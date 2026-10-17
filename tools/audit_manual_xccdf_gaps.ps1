param(
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputPath) {
  $OutputPath = Join-Path $repoRoot 'modules\stigs\MANUAL_XCCDF_GAPS.md'
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if (-not $resolvedOutput.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "OutputPath must remain inside the repository: $resolvedOutput"
}

$benchmarks = [ordered]@{
  '8' = [ordered]@{
    Label = 'RHEL 8 V2R8'
    RelativePath = 'ansible/U_RHEL_8_V2R8_STIG_Ansible/rhel8STIG-ansible/roles/rhel8STIG/files/U_RHEL_8_STIG_V2R8_Manual-xccdf.xml'
    DuplicatePath = 'ansible/U_RHEL_8_V2R8_STIG/U_RHEL_8_V2R8_Manual_STIG/U_RHEL_8_STIG_V2R8_Manual-xccdf.xml'
  }
  '9' = [ordered]@{
    Label = 'RHEL 9 V2R9'
    RelativePath = 'ansible/U_RHEL_9_V2R9_STIG_Ansible/rhel9STIG-ansible/roles/rhel9STIG/files/U_RHEL_9_STIG_V2R9_Manual-xccdf.xml'
    DuplicatePath = 'ansible/U_RHEL_9_V2R9_STIG/U_RHEL_9_V2R9_Manual_STIG/U_RHEL_9_STIG_V2R9_Manual-xccdf.xml'
  }
  '10' = [ordered]@{
    Label = 'RHEL 10 V1R2'
    RelativePath = 'ansible/U_RHEL_10_V1R2_STIG/U_RHEL_10_V1R2_Manual_STIG/U_RHEL_10_STIG_V1R2_Manual-xccdf.xml'
    DuplicatePath = $null
  }
}

function Markdown([string]$Value) {
  if ($null -eq $Value) { return '' }
  return (($Value -replace '\|', '\|') -replace '\s+', ' ').Trim()
}

function Category([string]$Title, [string]$Fix) {
  $text = $Title
  if ($text -match '(?i)package|software repositor|security patches|vendor-supported|subscription-manager|GPG signature|vendor software') {
    return 'Packages, updates, and repositories'
  }
  if ($text -match '(?i)file integrity|AIDE|fapolicyd|authorized software|unauthorized peripherals|USBGuard|malicious code') {
    return 'Integrity, application control, and peripherals'
  }
  if ($text -match '(?i)file system|filesystem|partition|mount point|\bmount\b|local disk|/home|/tmp|/var|/dev/shm') {
    return 'Filesystems, mounts, and storage'
  }
  if ($text -match '(?i)mode\s+["'']?[0-7]|owned by|group-owned|permission|sticky bit|world-writable|valid owner|valid group|access control program') {
    return 'File ownership and permissions'
  }
  if ($text -match '(?i)audit|audisp|\blog\b|logging|logon|journald|rsyslog') {
    return 'Audit and logging'
  }
  if ($text -match '(?i)password|authentication|account|\bPAM\b|login|sudo|privilege|root user|smart card|interactive user|UID|GID') {
    return 'Authentication, accounts, and privilege'
  }
  if ($text -match '(?i)cryptograph|certificate|\bFIPS\b|\bPKI\b|private key|trust anchor') {
    return 'Cryptography and PKI'
  }
  if ($text -match '(?i)Secure Shell|\bSSH\b|network|firewall|IPv4|IPv6|wireless|Bluetooth|\bNFS\b|SNMP|remote access|IP tunnel|mail relay|DNS') {
    return 'Network and remote access'
  }
  if ($text -match '(?i)graphical|display manager|\bGDM\b|dconf|screen lock|session lock') {
    return 'Graphical desktop and sessions'
  }
  if ($text -match '(?i)boot|kernel|memory|core dump|SELinux|system call|sysctl|processor-based|virtual syscall|page allocator') {
    return 'Boot, kernel, and runtime hardening'
  }
  if ($text -match '(?i)service|daemon|socket|systemd|target|timer|cron|at\.allow|scheduled') {
    return 'Services and scheduled execution'
  }
  return 'Other operational and inventory controls'
}

function Targets([string]$Title, [string]$Fix) {
  $values = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $text = "$Title`n$Fix"

  foreach ($match in [regex]::Matches($text, '(?<![A-Za-z0-9])/(?:etc|var|usr|boot|home|tmp|dev|proc|sys|run|root)(?:/[A-Za-z0-9_.*?@%{}<>=:+-]+)+')) {
    [void]$values.Add($match.Value.TrimEnd('.', ',', ';', ':', ')', '"', "'"))
  }
  foreach ($match in [regex]::Matches($text, '\b[A-Za-z0-9_@.-]+\.(?:service|socket|target|timer)\b')) {
    [void]$values.Add($match.Value)
  }
  foreach ($match in [regex]::Matches($Title, '["“]([^"”\r\n]{1,80})["”]')) {
    $value = $match.Groups[1].Value.Trim()
    if ($value -notmatch '\s{3,}') { [void]$values.Add($value) }
  }
  foreach ($line in ($Fix -split '\r?\n')) {
    $candidate = $line.Trim()
    if ($candidate -match '^[A-Za-z][A-Za-z0-9_.-]+\s*(?:=|\s)\s*(?:yes|no|true|false|none|verbose|[0-9-]+)(?:\s|$)' -and $candidate.Length -le 100) {
      [void]$values.Add($candidate)
    }
  }

  $selected = @($values | Sort-Object | Select-Object -First 8)
  if ($selected.Count -eq 0) { return 'Not identified' }
  return (($selected | ForEach-Object { "``$(Markdown $_)``" }) -join '<br>')
}

function Normalize([string]$Value) {
  return ((($Value.ToLowerInvariant() -replace '\s*=\s*', '=') -replace '[ \t]+', ' ').Replace('"', '').Replace("'", '')).Trim()
}

function SettingLines([string]$Fix) {
  $settings = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($rawLine in ($Fix -split '\r?\n')) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.Length -gt 180) { continue }
    if ($line -match '^\$|^#|^(Configure|Create|Edit|Add |Run |Restart|Reload|Remove|Set |If |Note:|The |For |Ensure |Replace |Verify |Check |This )') { continue }
    if ($line.EndsWith(':')) { continue }
    $isSetting = $line -match '^(?:-a |-w |auth\s|account\s|password\s|session\s)' -or
      $line -match '^[A-Za-z][A-Za-z0-9_.-]+\s*=\s*\S' -or
      $line -match '^[A-Za-z][A-Za-z0-9_.-]+\s+(?:yes|no|true|false|none|verbose|[0-9-]+)(?:\s|$)'
    if ($isSetting) { [void]$settings.Add($line) }
  }
  return @($settings)
}

$moduleFiles = @(
  Get-ChildItem -Path (Join-Path $repoRoot 'modules\stigs\files') -Recurse -File
  Get-ChildItem -Path (Join-Path $repoRoot 'modules\stigs\manifests') -Recurse -File -Filter '*.pp'
)
$moduleText = (($moduleFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n")
$normalizedModuleText = Normalize $moduleText
$results = [ordered]@{}

foreach ($os in $benchmarks.Keys) {
  $benchmark = $benchmarks[$os]
  $path = Join-Path $repoRoot $benchmark.RelativePath
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing benchmark: $path" }
  $benchmark.Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
  if ($benchmark.DuplicatePath) {
    $benchmark.DuplicateStatus = 'Optional standalone copy must be byte-identical when present'
    $duplicate = Join-Path $repoRoot $benchmark.DuplicatePath
    if (Test-Path -LiteralPath $duplicate) {
      $duplicateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $duplicate).Hash
      if ($duplicateHash -ne $benchmark.Hash) {
        throw "Benchmark copies differ for RHEL $os"
      }
    }
  } else {
    $benchmark.DuplicateStatus = 'No duplicate copy'
  }

  [xml]$document = [IO.File]::ReadAllText($path)
  $namespace = [Xml.XmlNamespaceManager]::new($document.NameTable)
  $namespace.AddNamespace('xccdf', $document.DocumentElement.NamespaceURI)
  $releaseNode = $document.SelectSingleNode('//xccdf:plain-text[@id="release-info"]', $namespace)
  $benchmark.ReleaseInfo = $releaseNode.InnerText.Trim()

  $rows = foreach ($group in @($document.SelectNodes('//xccdf:Group[xccdf:Rule]', $namespace))) {
    $vId = [string]$group.id
    $rule = $group.SelectSingleNode('xccdf:Rule', $namespace)
    $title = $rule.SelectSingleNode('xccdf:title', $namespace).InnerText.Trim()
    $fixNode = $rule.SelectSingleNode('xccdf:fixtext', $namespace)
    $fix = if ($fixNode) { $fixNode.InnerText.Trim() } else { '' }
    $settings = @(SettingLines $fix)
    $matchingSettings = @($settings | Where-Object { $normalizedModuleText.Contains((Normalize $_)) })
    $crossCheck = if ($matchingSettings.Count -gt 0) {
      'Matching setting text exists without `V-` trace: ' + (($matchingSettings | ForEach-Object { "``$(Markdown $_)``" }) -join '<br>')
    } else {
      'No exact `V-` ID or extracted setting-line match'
    }
    [pscustomobject]@{
      V = $vId
      Rule = [string]$rule.version
      Severity = [string]$rule.severity
      Title = $title
      Fix = $fix
      Category = Category $title $fix
      Targets = Targets $title $fix
      MatchingSettings = $matchingSettings
      CrossCheck = $crossCheck
      Represented = $moduleText.Contains($vId)
    }
  }
  $results[$os] = @($rows)
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Manual XCCDF settings not represented in the STIG module')
$lines.Add('')
$lines.Add('Generated by `tools/audit_manual_xccdf_gaps.ps1` from the manual XCCDF files in `ansible/`.')
$lines.Add('')
$lines.Add('## Scope and interpretation')
$lines.Add('')
$lines.Add('A rule is listed when its exact DISA `V-` identifier does not occur in either `modules/stigs/manifests/*.pp` or any asset below `modules/stigs/files/`. The requirement title and concrete targets are taken from that rule in the manual XCCDF. This is a conservative traceability gap report: a setting may exist incidentally without its `V-` identifier, but it is not represented as an implemented control and requires review. The repository cross-check calls out exact configuration lines from the XCCDF fix text that do appear elsewhere in the module; those rows are traceability or release-applicability questions rather than proven missing directives. Conversely, controls whose identifiers appear in the module are outside this report; this audit does not prove that those implementations are complete or compliant on a deployed host.')
$lines.Add('')
$lines.Add('Package and service maps that are guarded away from an OS do not count as implementation for that release unless its `V-` identifier is explicitly represented. Site-specific, hardware-dependent, partitioning, runtime-inventory, and manual-review requirements remain listed because the current static files and manifests do not express them.')
$lines.Add('')
$lines.Add('## Benchmarks')
$lines.Add('')
$lines.Add('| OS | Canonical XML | Release information | SHA-256 | Duplicate check |')
$lines.Add('|---|---|---|---|---|')
foreach ($os in $benchmarks.Keys) {
  $benchmark = $benchmarks[$os]
  $lines.Add("| RHEL $os | ``$($benchmark.RelativePath)`` | $(Markdown $benchmark.ReleaseInfo) | ``$($benchmark.Hash)`` | $($benchmark.DuplicateStatus) |")
}
$lines.Add('')
$lines.Add('## Summary')
$lines.Add('')
$lines.Add('| OS | XCCDF rules | Represented `V-` IDs | No `V-` mapping | No setting-line match | Exact line exists but is unmapped | High | Medium | Low |')
$lines.Add('|---|---:|---:|---:|---:|---:|---:|---:|---:|')
foreach ($os in $benchmarks.Keys) {
  $rows = $results[$os]
  $missing = @($rows | Where-Object { -not $_.Represented })
  $matchedSettings = @($missing | Where-Object { $_.MatchingSettings.Count -gt 0 }).Count
  $lines.Add("| RHEL $os | $($rows.Count) | $(@($rows | Where-Object Represented).Count) | $($missing.Count) | $($missing.Count - $matchedSettings) | $matchedSettings | $(@($missing | Where-Object Severity -eq 'high').Count) | $(@($missing | Where-Object Severity -eq 'medium').Count) | $(@($missing | Where-Object Severity -eq 'low').Count) |")
}
$allMissing = @($results.Keys | ForEach-Object { $results[$_] | Where-Object { -not $_.Represented } })
$allRows = @($results.Keys | ForEach-Object { $results[$_] })
$allMatchedSettings = @($allMissing | Where-Object { $_.MatchingSettings.Count -gt 0 }).Count
$lines.Add("| **Total** | **$($allRows.Count)** | **$(@($allRows | Where-Object Represented).Count)** | **$($allMissing.Count)** | **$($allMissing.Count - $allMatchedSettings)** | **$allMatchedSettings** | **$(@($allMissing | Where-Object Severity -eq 'high').Count)** | **$(@($allMissing | Where-Object Severity -eq 'medium').Count)** | **$(@($allMissing | Where-Object Severity -eq 'low').Count)** |")
$lines.Add('')
$lines.Add("Of the $($allMissing.Count) rules without a `V-` mapping, $allMatchedSettings have at least one exact setting line from the XCCDF fix text elsewhere in the module. Those rows are explicitly marked for traceability and OS-applicability review; the remaining $($allMissing.Count - $allMatchedSettings) have no extracted setting-line match.")
$lines.Add('')
$lines.Add('### Unrepresented settings by category')
$lines.Add('')
$categories = @($allMissing.Category | Sort-Object -Unique)
$lines.Add('| Category | RHEL 8 | RHEL 9 | RHEL 10 | Total |')
$lines.Add('|---|---:|---:|---:|---:|')
foreach ($category in $categories) {
  $counts = foreach ($os in $benchmarks.Keys) { @($results[$os] | Where-Object { -not $_.Represented -and $_.Category -eq $category }).Count }
  $lines.Add("| $(Markdown $category) | $($counts[0]) | $($counts[1]) | $($counts[2]) | $([int]$counts[0] + [int]$counts[1] + [int]$counts[2]) |")
}
$lines.Add('')
$lines.Add('## Detailed unrepresented settings')
$lines.Add('')
foreach ($os in $benchmarks.Keys) {
  $missing = @($results[$os] | Where-Object { -not $_.Represented })
  $lines.Add("### RHEL $os")
  $lines.Add('')
  foreach ($category in @($missing.Category | Sort-Object -Unique)) {
    $categoryRows = @($missing | Where-Object Category -eq $category | Sort-Object V)
    $lines.Add("#### $category ($($categoryRows.Count))")
    $lines.Add('')
    $lines.Add('| V ID | Rule | Severity | Required setting or action | XCCDF targets/directives | Repository cross-check |')
    $lines.Add('|---|---|---|---|---|---|')
    foreach ($row in $categoryRows) {
      $lines.Add("| $($row.V) | $($row.Rule) | $($row.Severity) | $(Markdown $row.Title) | $($row.Targets) | $($row.CrossCheck) |")
    }
    $lines.Add('')
  }
}

[IO.Directory]::CreateDirectory((Split-Path $resolvedOutput -Parent)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, (($lines -join "`n").TrimEnd() + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "Wrote $resolvedOutput with $($allMissing.Count) unrepresented settings."
