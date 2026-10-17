param(
  [Parameter(Mandatory)]
  [string]$SnapshotRoot,
  [string]$InventoryRoot = (Join-Path $PSScriptRoot '..\.ps_sandbox\merged_stigs'),
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\.ps_sandbox\controlled_exemplars'),
  [string[]]$Majors = @('8', '9')
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)

function Write-Lines([string]$Path, [string[]]$Lines) {
  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force $parent | Out-Null
  $normalized = [Collections.Generic.List[string]]::new()
  foreach ($line in $Lines) {
    # Preserve an escaped terminal space in shell syntax; discard other
    # non-semantic trailing whitespace inherited from vendor comments/files.
    $normalized.Add($(if ($line.EndsWith('\ ')) { $line } else { $line.TrimEnd() }))
  }
  # A single newline terminates the file; do not retain empty records after
  # the last meaningful line from a vendor exemplar.
  while ($normalized.Count -and $normalized[$normalized.Count - 1] -eq '') {
    $normalized.RemoveAt($normalized.Count - 1)
  }
  [IO.File]::WriteAllText($Path, (($normalized -join "`n") + "`n"), $utf8NoBom)
}

function Destination([string]$Relative) {
  if ($Relative.StartsWith('usr/') -or $Relative.StartsWith('etc/')) { return "/$Relative" }
  return "/etc/$Relative"
}

function Find-Overlay([string]$Relative, [string]$Major) {
  # Keep the canonical RHEL 8 USG wording for the common text banners. The
  # generated RHEL 9 graphical fragment only enables the banner and otherwise
  # would omit the required message text.
  $overlayMajor = if ($Major -in @('8', '9') -and $Relative -in @('dconf/db/local.d/01-banner-message', 'etc/issue')) { '8' } else { $Major }
  $overlay = Join-Path $InventoryRoot "$overlayMajor\files\$($Relative.Replace('/', '\'))"
  if (Test-Path -LiteralPath $overlay) { return $overlay }
  throw "No controlled overlay found for RHEL $Major $Relative"
}

function Active-Line([string]$Line) {
  $trimmed = $Line.Trim()
  return $trimmed -and -not $trimmed.StartsWith('#') -and -not $trimmed.StartsWith(';')
}

function Merge-Ini([string[]]$Base, [string[]]$Overlay) {
  $result = [Collections.Generic.List[string]]::new()
  if ($Base) { $result.AddRange([string[]]$Base) }
  $overlaySection = ''

  foreach ($line in $Overlay) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) { continue }
    if ($trimmed -match '^\[(.+)\]$') {
      $overlaySection = $Matches[1]
      if (-not ($result | Where-Object { $_.Trim() -ieq "[$overlaySection]" })) {
        if ($result.Count -and $result[$result.Count - 1] -ne '') { $result.Add('') }
        $result.Add("[$overlaySection]")
      }
      continue
    }

    $key = if ($trimmed -match '^([^=\s]+)\s*=') { $Matches[1] } else { $trimmed }
    $currentSection = ''
    $matchedIndexes = [Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $result.Count; $i++) {
      $candidate = $result[$i].Trim()
      if ($candidate -match '^\[(.+)\]$') { $currentSection = $Matches[1]; continue }
      if ($currentSection -ine $overlaySection -or -not (Active-Line $candidate)) { continue }
      $candidateKey = if ($candidate -match '^([^=\s]+)\s*=') { $Matches[1] } else { $candidate }
      if ($candidateKey -ieq $key) { $matchedIndexes.Add($i) }
    }

    if ($matchedIndexes.Count) {
      $result[$matchedIndexes[0]] = $line
      for ($i = $matchedIndexes.Count - 1; $i -ge 1; $i--) { $result.RemoveAt($matchedIndexes[$i]) }
      continue
    }

    $insertAt = $result.Count
    if ($overlaySection) {
      $inSection = $false
      for ($i = 0; $i -lt $result.Count; $i++) {
        if ($result[$i].Trim() -match '^\[(.+)\]$') {
          if ($inSection) { $insertAt = $i; break }
          $inSection = ($Matches[1] -ieq $overlaySection)
        }
      }
    }
    $result.Insert($insertAt, $line)
  }
  return $result.ToArray()
}

function Merge-Directives([string[]]$Base, [string[]]$Overlay, [scriptblock]$Identity, [switch]$AppendOnly) {
  $result = [Collections.Generic.List[string]]::new()
  if ($Base) { $result.AddRange([string[]]$Base) }
  foreach ($line in $Overlay) {
    if (-not (Active-Line $line)) { continue }
    $identityValue = & $Identity $line
    $matchedIndexes = [Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $result.Count; $i++) {
      if ((Active-Line $result[$i]) -and ((& $Identity $result[$i]) -ieq $identityValue)) { $matchedIndexes.Add($i) }
    }
    if ($matchedIndexes.Count -and -not $AppendOnly) {
      $result[$matchedIndexes[0]] = $line
      for ($i = $matchedIndexes.Count - 1; $i -ge 1; $i--) { $result.RemoveAt($matchedIndexes[$i]) }
    } elseif (-not ($result | Where-Object { $_.Trim() -eq $line.Trim() })) {
      if ($result.Count -and $result[$result.Count - 1] -ne '') { $result.Add('') }
      $result.Add($line)
    }
  }
  return $result.ToArray()
}

function Merge-AuditRules([string[]]$Base, [string[]]$Overlay) {
  $result = [Collections.Generic.List[string]]::new()
  if ($Base) { $result.AddRange([string[]]$Base) }
  $immutable = $null
  foreach ($line in $Overlay) {
    $trimmed = ($line -replace '\s+', ' ').Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -match '^-e\s+') { $immutable = $line; continue }
    if ($trimmed -match '^-f\s+') {
      for ($i = $result.Count - 1; $i -ge 0; $i--) {
        if ($result[$i].Trim() -match '^-f\s+') { $result.RemoveAt($i) }
      }
    }
    $present = $result | Where-Object { (($_ -replace '\s+', ' ').Trim()) -eq $trimmed }
    if (-not $present) { $result.Add($line) }
  }
  for ($i = $result.Count - 1; $i -ge 0; $i--) {
    if ($result[$i].Trim() -match '^-e\s+') { $result.RemoveAt($i) }
  }
  if ($immutable) { $result.Add($immutable) }
  return $result.ToArray()
}

function Merge-Sshd([string[]]$Base, [string[]]$Overlay) {
  $result = [Collections.Generic.List[string]]::new()
  if ($Base) { $result.AddRange([string[]]$Base) }
  $pending = [Collections.Generic.List[string]]::new()
  foreach ($line in $Overlay) {
    if (-not (Active-Line $line)) { continue }
    $key = ($line.Trim() -split '\s+', 2)[0]
    $matchedIndexes = [Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $result.Count; $i++) {
      if (-not (Active-Line $result[$i])) { continue }
      if ((($result[$i].Trim() -split '\s+', 2)[0]) -ieq $key) { $matchedIndexes.Add($i) }
    }
    if ($matchedIndexes.Count) {
      $result[$matchedIndexes[0]] = $line
      for ($i = $matchedIndexes.Count - 1; $i -ge 1; $i--) { $result.RemoveAt($matchedIndexes[$i]) }
    } else {
      $pending.Add($line)
    }
  }
  if ($pending.Count) {
    $insertAt = $result.Count
    for ($i = 0; $i -lt $result.Count; $i++) {
      if ($result[$i].Trim() -match '^(?i:Include|Match)\s+') { $insertAt = $i; break }
    }
    $result.InsertRange($insertAt, [string[]]$pending)
  }
  return $result.ToArray()
}

function Remove-DconfCrossOwnedSettings([string]$Relative, [string[]]$Base) {
  $ownedElsewhere = switch ($Relative) {
    'dconf/db/local.d/00-security-settings' {
      @(
        'org/gnome/desktop/screensaver|lock-enabled',
        'org/gnome/desktop/screensaver|lock-delay',
        'org/gnome/desktop/session|idle-delay',
        'org/gnome/settings-daemon/plugins/media-keys|logout'
      )
    }
    'dconf/db/local.d/locks/00-security-settings-lock' {
      @(
        '/org/gnome/desktop/screensaver/lock-enabled',
        '/org/gnome/desktop/screensaver/lock-delay',
        '/org/gnome/desktop/session/idle-delay'
      )
    }
    default { @() }
  }
  if (-not $ownedElsewhere.Count) { return $Base }
  $section = ''
  $filtered = [Collections.Generic.List[string]]::new()
  foreach ($line in $Base) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^\[(.+)\]$') { $section = $Matches[1]; $filtered.Add($line); continue }
    $identity = if ($trimmed -match '^([^=\s]+)\s*=') { "$section|$($Matches[1])" } else { $trimmed }
    if ($identity -notin $ownedElsewhere) { $filtered.Add($line) }
  }
  return $filtered.ToArray()
}

function Merge-File([string]$Relative, [string[]]$Base, [string[]]$Overlay) {
  switch -Regex ($Relative) {
    '^etc/issue$' { return $Overlay }
    '^audit/rules\.d/' { return Merge-AuditRules $Base $Overlay }
    '^systemd/coredump\.conf$' {
      # The Ansible fragment contains bare keys, but the vendor file keeps
      # them in [Coredump]. Supply the semantic section so existing keys are
      # replaced instead of duplicated after the section.
      $sectionOverlay = if ($Overlay | Where-Object { $_.Trim() -eq '[Coredump]' }) { $Overlay } else { @('[Coredump]') + $Overlay }
      return Merge-Ini $Base $sectionOverlay
    }
    '^(dconf/.+|dnf/|firewalld/|gdm/|NetworkManager/|etc/(libuser|opensc)|security/(faillock|pwquality)|selinux/|sssd/|sysctl\.d/|systemd/|usr/lib/systemd/system/)' {
      return Merge-Ini $Base $Overlay
    }
    '^audit/auditd\.conf$' { return Merge-Ini $Base $Overlay }
    '^etc/(login\.defs|chrony\.conf)$' {
      return Merge-Directives $Base $Overlay { param($line) ($line.Trim() -split '\s+', 2)[0] }
    }
    '^ssh/sshd_config$' {
      return Merge-Sshd $Base $Overlay
    }
    '^etc/aliases$' {
      return Merge-Directives $Base $Overlay { param($line) ($line.Trim() -split ':', 2)[0] }
    }
    '^security/limits\.conf$' {
      return Merge-Directives $Base $Overlay { param($line) (($line.Trim() -split '\s+')[0..2] -join '|') }
    }
    '^modprobe\.d/' {
      return Merge-Directives $Base $Overlay { param($line) (($line.Trim() -split '\s+')[0..1] -join '|') }
    }
    '^etc/rsyslog\.conf$' {
      return Merge-Directives $Base $Overlay { param($line) if ($line.Trim().StartsWith('$')) { ($line.Trim() -split '\s+', 2)[0] } else { $line.Trim() } }
    }
    '^etc/sudoers$' {
      return Merge-Directives $Base $Overlay { param($line) $line.Trim() } -AppendOnly
    }
    '^profile\.d/tmout\.sh$' {
      return Merge-Directives $Base $Overlay { param($line) if ($line -match 'TMOUT\s*=') { 'TMOUT' } else { $line.Trim() } }
    }
    '^etc/(bashrc|csh\.cshrc|profile)$' {
      return Merge-Directives $Base $Overlay { param($line) $line.Trim() } -AppendOnly
    }
    default {
      return Merge-Directives $Base $Overlay { param($line) $line.Trim() } -AppendOnly
    }
  }
}

$resolvedSnapshot = (Resolve-Path $SnapshotRoot).Path
$resolvedInventory = (Resolve-Path $InventoryRoot).Path
$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
if ($resolvedOutput -eq $resolvedSnapshot -or $resolvedOutput -eq $resolvedInventory) {
  throw "OutputRoot must not overwrite an input tree: $resolvedOutput"
}
if (Test-Path -LiteralPath $resolvedOutput) {
  throw "OutputRoot already exists: $resolvedOutput"
}

$report = [Collections.Generic.List[object]]::new()
foreach ($major in $Majors) {
  $inventoryFiles = Join-Path $resolvedInventory "$major\files"
  $inventoryBase = (Resolve-Path $inventoryFiles).Path
  foreach ($inventoryFile in Get-ChildItem -Recurse -File $inventoryBase | Sort-Object FullName) {
    $relative = $inventoryFile.FullName.Substring($inventoryBase.Length + 1).Replace('\', '/')
    $destination = Destination $relative
    $overlayPath = Find-Overlay $relative $major
    $snapshotPath = Join-Path (Join-Path $resolvedSnapshot $major) $destination.TrimStart('/').Replace('/', '\')
    $baseExists = Test-Path -LiteralPath $snapshotPath
    $base = if ($baseExists) { [IO.File]::ReadAllLines($snapshotPath) } else { @() }
    $overlay = [IO.File]::ReadAllLines($overlayPath)
    if ($baseExists -and $relative.StartsWith('dconf/')) {
      $base = Remove-DconfCrossOwnedSettings $relative $base
    }
    $merged = if ($baseExists) { Merge-File $relative $base $overlay } else { $overlay }
    $outputPath = Join-Path $resolvedOutput "$major\files\$($relative.Replace('/', '\'))"
    Write-Lines $outputPath $merged
    $report.Add([pscustomobject]@{
      os = $major
      source = $relative
      destination = $destination
      base_found = $baseExists
      base_lines = $base.Count
      overlay_lines = $overlay.Count
      result_lines = $merged.Count
    })
  }
}

New-Item -ItemType Directory -Force $resolvedOutput | Out-Null
$report | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $resolvedOutput 'merge-report.json')
Write-Host "Generated $($report.Count) merged exemplars in $resolvedOutput"
