param(
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\modules\stigs'),
  [string]$SnapshotRoot
)

$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$extractor = Join-Path $PSScriptRoot 'generate_rhel8_stigs.ps1'
$staging = Join-Path $repo '.ps_sandbox\merged_stigs'
$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
$resolvedRepo = [IO.Path]::GetFullPath($repo)
if (-not $resolvedOutput.StartsWith($resolvedRepo, [StringComparison]::OrdinalIgnoreCase)) {
  throw "OutputRoot must remain inside the repository: $resolvedOutput"
}
$roots = @{
  '8' = Join-Path $repo 'ansible\U_RHEL_8_V2R8_STIG_Ansible\rhel8STIG-ansible\roles\rhel8STIG'
  '9' = Join-Path $repo 'ansible\U_RHEL_9_V2R9_STIG_Ansible\rhel9STIG-ansible\roles\rhel9STIG'
}

function Quote([string]$value) { "'" + $value.Replace('\','\\').Replace("'","\\'") + "'" }
function Destination([string]$relative) {
  $p = $relative.Replace('\','/')
  if ($p.StartsWith('usr/')) { return "/$p" }
  if ($p.StartsWith('etc/')) { return "/$p" }
  return "/etc/$p"
}
function ClassName([string]$path) {
  if ($path.StartsWith('/etc/')) {
    $r = $path.Substring(5)
    if ($r.Contains('/')) { return (($r.Split('/')[0] -replace '[^A-Za-z0-9_]', '_').ToLower()) }
    return 'etc'
  }
  if ($path.StartsWith('/usr/lib/systemd/system/')) { return 'systemd_units' }
  if ($path.StartsWith('/boot/')) { return 'boot' }
  if ($path.StartsWith('/var/')) { return 'var' }
  return 'system'
}
function Notification([string]$path) {
  switch -Regex ($path) {
    '^/etc/ssh/' { return "Service['sshd.service']" }
    '^/etc/audit/' { return "Exec['reload audit rules']" }
    '^/etc/rsyslog' { return "Service['rsyslog.service']" }
    '^/etc/sysctl.d/' { return "Exec['reload sysctl settings']" }
    '^/etc/dconf/' { return "Exec['update dconf database']" }
    '^/(etc|usr/lib)/systemd/' { return "Exec['systemd daemon reload']" }
    default { return $null }
  }
}
function Attr([object]$permission, [string]$name, [string]$fallback) {
  if ($permission -and $permission.PSObject.Properties.Name -contains $name) { return [string]$permission.$name }
  return $fallback
}
function FileResource([string]$path, [string]$source, [object]$permission, [string]$indent = '  ') {
  $owner = Attr $permission 'owner' 'root'
  $group = Attr $permission 'group' 'root'
  $defaultMode = switch -Regex ($path) {
    '^/etc/sudoers$' { '0440'; break }
    '^/etc/sssd/' { '0600'; break }
    '^/etc/audit/' { '0640'; break }
    default { '0644' }
  }
  $mode = Attr $permission 'mode' $defaultMode
  $notify = Notification $path
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add("${indent}file { $(Quote "stig $path"):")
  $lines.Add("${indent}  ensure => file,")
  $lines.Add("${indent}  path   => $(Quote $path),")
  $lines.Add("${indent}  owner  => $(Quote $owner),")
  $lines.Add("${indent}  group  => $(Quote $group),")
  $lines.Add("${indent}  mode   => $(Quote $mode),")
  $lines.Add("${indent}  source       => stigs::source_candidates($(Quote ($source -replace '\.(8|9|10)$', ''))),")
  $lines.Add("${indent}  sourceselect => 'first',")
  if ($notify) { $lines.Add("${indent}  notify => $notify,") }
  $lines.Add("${indent}}")
  return $lines -join "`n"
}
foreach ($major in @('8','9')) {
  $out = Join-Path $staging $major
  if (Test-Path $out) { Remove-Item -Recurse -Force -LiteralPath $out }
  & $extractor -RoleRoot $roots[$major] -OutputRoot $out
}

$assetRoots = @{
  '8' = Join-Path $staging '8\files'
  '9' = Join-Path $staging '9\files'
}
if ($SnapshotRoot) {
  $exemplarMerger = Join-Path $PSScriptRoot 'merge_stig_exemplars.ps1'
  $exemplarOutput = Join-Path $repo '.ps_sandbox\merged_exemplars'
  if (Test-Path $exemplarOutput) { Remove-Item -Recurse -Force -LiteralPath $exemplarOutput }
  & $exemplarMerger -SnapshotRoot $SnapshotRoot -InventoryRoot $staging -OutputRoot $exemplarOutput
  $assetRoots = @{
    '8' = Join-Path $exemplarOutput '8\files'
    '9' = Join-Path $exemplarOutput '9\files'
  }
}

$inventory = @{}
foreach ($major in @('8','9')) {
  $inventory[$major] = Get-Content -Raw (Join-Path $staging "$major\generated-inventory.json") | ConvertFrom-Json
}

# Supplement the DISA Ansible inventories with controls confirmed against the
# installed SSG profiles and the newer manual XCCDF shipped with the roles.
function Set-InventoryProperty([object]$Object, [string]$Name, [object]$Value) {
  $property = $Object.PSObject.Properties[$Name]
  if ($property) { $property.Value = $Value }
  else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}
function Add-InventoryControls([string]$Major, [string]$ClassName, [string[]]$Ids) {
  $property = $inventory[$Major].control_map.PSObject.Properties[$ClassName]
  $current = if ($property) { @($property.Value) } else { @() }
  Set-InventoryProperty $inventory[$Major].control_map $ClassName (@($current + $Ids | Sort-Object -Unique))
}

$packageSupplements = @{
  '8' = [ordered]@{
    'aide' = 'installed'; 'fapolicyd' = 'installed'; 'krb5-server' = 'absent'
    'postfix' = 'installed'; 'usbguard' = 'installed'
  }
  '9' = [ordered]@{ 'aide' = 'installed'; 'cronie' = 'installed'; 'tftp-server' = 'absent' }
}
foreach ($major in @('8','9')) {
  foreach ($entry in $packageSupplements[$major].GetEnumerator()) {
    Set-InventoryProperty $inventory[$major].packages $entry.Key $entry.Value
  }
}

$serviceSupplements8 = [ordered]@{
  'debug-shell.service' = [pscustomobject]@{ ensure = 'stopped'; enable = $false; masked = $true }
  'fapolicyd.service'   = [pscustomobject]@{ ensure = 'running'; enable = $true; masked = $false }
  'firewalld.service'   = [pscustomobject]@{ ensure = 'running'; enable = $true; masked = $false }
  'kdump.service'       = [pscustomobject]@{ ensure = 'stopped'; enable = $false; masked = $false }
  'sshd.service'        = [pscustomobject]@{ ensure = 'running'; enable = $true; masked = $false }
  'usbguard.service'    = [pscustomobject]@{ ensure = 'running'; enable = $true; masked = $false }
}
foreach ($entry in $serviceSupplements8.GetEnumerator()) {
  Set-InventoryProperty $inventory['8'].services $entry.Key $entry.Value
}

Add-InventoryControls '8' 'packages' @('V-230389','V-230523','V-237640','V-244547','V-251710')
Add-InventoryControls '8' 'services' @('V-244545','V-244548')
Add-InventoryControls '8' 'sssd' @('V-230274','V-230369')
Add-InventoryControls '9' 'packages' @('V-257835','V-257888','V-258134')
Add-InventoryControls '9' 'audit' @('V-258215','V-258216')
Add-InventoryControls '9' 'sssd' @('V-258123')

$rhel10PackageControlIds = @(
  'V-280943','V-280944','V-280945','V-280946','V-280947','V-280948','V-280949','V-280950',
  'V-280951','V-280952','V-280953','V-280954','V-280955','V-280958','V-280962','V-280966',
  'V-280967','V-280968','V-280972','V-280974','V-280975','V-280977','V-280983','V-280992',
  'V-280993','V-280995','V-280996','V-281000','V-281001','V-281003','V-281005','V-281006',
  'V-281007'
)
$rhel10ServiceControlIds = @(
  'V-280094','V-280956','V-280959','V-280963','V-280970','V-280973','V-280984','V-280994',
  'V-281002','V-281096','V-281290','V-281299','V-281320','V-281322','V-281323'
)
$permissionControlIds = @{
  '8' = @('V-230245','V-230246','V-230247','V-230248','V-230249','V-230250')
  '9' = @(
    'V-257790','V-257791','V-257885','V-257886','V-257891','V-257892','V-257893','V-257894',
    'V-257895','V-257896','V-257897','V-257898','V-257899','V-257900','V-257901','V-257902',
    'V-257903','V-257904','V-257905','V-257906','V-257907','V-257908','V-257909','V-257910',
    'V-257911','V-257912','V-257913','V-257914','V-257915','V-257916','V-257917','V-257934'
  )
  '10' = @(
    'V-281017','V-281018','V-281019','V-281020','V-281021','V-281022','V-281023','V-281024',
    'V-281025','V-281026','V-281027','V-281028','V-281029','V-281030','V-281031','V-281032',
    'V-281033','V-281034','V-281035','V-281036','V-281061','V-281062','V-281066','V-281067',
    'V-281068','V-281069','V-281070','V-281071','V-281072','V-281076'
  )
}

foreach ($major in @('8','9')) {
  foreach ($property in @($inventory[$major].control_map.PSObject.Properties)) {
    $property.Value = @($property.Value | Where-Object { $_ -notin $permissionControlIds[$major] })
  }
  Set-InventoryProperty $inventory[$major].control_map 'permissions' $permissionControlIds[$major]
}

function ControlHeader([string]$className) {
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add('# DISA STIG vulnerability IDs implemented by this class:')
  foreach ($major in @('8','9')) {
    $property = $inventory[$major].control_map.PSObject.Properties | Where-Object { $_.Name -ieq $className } | Select-Object -First 1
    $ids = if ($property) { @($property.Value | Sort-Object { [int]($_ -replace '^V-','') }) } else { @() }
    if ($ids.Count -eq 0) {
      $lines.Add("# RHEL ${major}: none directly")
      continue
    }
    $lines.Add("# RHEL ${major}:")
    for ($i = 0; $i -lt $ids.Count; $i += 8) {
      $end = [Math]::Min($i + 7, $ids.Count - 1)
      $lines.Add('#   ' + (($ids[$i..$end]) -join ', '))
    }
  }
  if ($className -eq 'packages') {
    $lines.Add('# RHEL 10:')
    for ($i = 0; $i -lt $rhel10PackageControlIds.Count; $i += 8) {
      $end = [Math]::Min($i + 7, $rhel10PackageControlIds.Count - 1)
      $lines.Add('#   ' + (($rhel10PackageControlIds[$i..$end]) -join ', '))
    }
  } elseif ($className -eq 'services') {
    $lines.Add('# RHEL 10:')
    for ($i = 0; $i -lt $rhel10ServiceControlIds.Count; $i += 8) {
      $end = [Math]::Min($i + 7, $rhel10ServiceControlIds.Count - 1)
      $lines.Add('#   ' + (($rhel10ServiceControlIds[$i..$end]) -join ', '))
    }
  } elseif ($className -eq 'permissions') {
    $lines.Add('# RHEL 10:')
    for ($i = 0; $i -lt $permissionControlIds['10'].Count; $i += 8) {
      $end = [Math]::Min($i + 7, $permissionControlIds['10'].Count - 1)
      $lines.Add('#   ' + (($permissionControlIds['10'][$i..$end]) -join ', '))
    }
  }
  return ($lines -join "`n") + "`n"
}
$assets = @{}
$canonicalCommonAssets = @{
  # The RHEL 8/9 banners differ only by spaces around "--"; use RHEL 9 wording.
  'etc/issue'      = '9'
  # Active SELinux settings match; use the reviewed RHEL 9 vendor comments.
  'selinux/config' = '9'
}
if (-not $SnapshotRoot) {
  # The fragment-only releases set the same values in a different order. Full
  # exemplar files retain their release-specific vendor comments and defaults.
  $canonicalCommonAssets['systemd/coredump.conf'] = '9'
}
foreach ($major in @('8','9')) {
  $base = (Resolve-Path $assetRoots[$major]).Path
  foreach ($file in Get-ChildItem -Recurse -File $base) {
    $relative = $file.FullName.Substring($base.Length + 1).Replace('\','/')
    if (-not $assets.ContainsKey($relative)) { $assets[$relative] = @{} }
    $assets[$relative][$major] = $file.FullName
  }
}

# Add small, reviewed SSG supplements that are absent from the generated
# Ansible fragments. These files stay in staging so OutputRoot can be rebuilt.
$supplementRoot = Join-Path $staging 'ssg_supplements'
New-Item -ItemType Directory -Force (Join-Path $supplementRoot '8\sssd\conf.d'), (Join-Path $supplementRoot '9\sssd\conf.d') | Out-Null
$certificate8 = Join-Path $supplementRoot '8\sssd\conf.d\certificate_verification.conf'
$certificate9 = Join-Path $supplementRoot '9\sssd\conf.d\certificate_verification.conf'
[IO.File]::WriteAllText($certificate8, "[sssd]`ncertificate_verification = ocsp_dgst=sha1`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($certificate9, "[sssd]`ncertificate_verification = ocsp_dgst=sha512`n", [Text.UTF8Encoding]::new($false))
$assets['sssd/conf.d/certificate_verification.conf'] = @{ '8' = $certificate8; '9' = $certificate9 }
if ($assets.ContainsKey('sssd/sssd.conf') -and $assets['sssd/sssd.conf'].ContainsKey('9')) {
  $assets['sssd/sssd.conf']['8'] = $assets['sssd/sssd.conf']['9']
}

# Keep the authoritative RHEL 9 audit asset aligned with the V2R9 manual
# XCCDF while accepting the SSG profile's semantically equivalent grouping.
$audit9 = Join-Path $assetRoots['9'] 'audit\rules.d\audit.rules'
if (-not (Test-Path -LiteralPath $audit9)) { throw "Missing RHEL 9 audit asset: $audit9" }
$auditLines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $audit9)
for ($i = 0; $i -lt $auditLines.Count; $i++) {
  $auditLines[$i] = $auditLines[$i].Replace('/etc/opasswd', '/etc/security/opasswd')
}
$auditSupplements = @(
  '-a always,exit -F arch=b32 -S umount,umount2 -F auid>=1000 -F auid!=unset -k privileged-umount'
  '-a always,exit -F arch=b64 -S umount2 -F auid>=1000 -F auid!=unset -k privileged-umount'
  '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/etc/group -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/etc/gshadow -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/etc/security/opasswd -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/etc/passwd -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/etc/shadow -F perm=wa -k identity'
  '-a always,exit -F arch=b32 -F path=/var/log/faillock -F perm=wa -F auid>=1000 -F auid!=unset -k logins'
  '-a always,exit -F arch=b32 -F path=/var/log/lastlog -F perm=wa -F auid>=1000 -F auid!=unset -k logins'
  '-w /etc/cron.d/ -p wa -k cronjobs'
  '-w /var/spool/cron/ -p wa -k cronjobs'
)
$insertAt = $auditLines.IndexOf('-e 2')
if ($insertAt -lt 0) { $insertAt = $auditLines.Count }
foreach ($rule in $auditSupplements) {
  if (-not $auditLines.Contains($rule)) { $auditLines.Insert($insertAt, $rule); $insertAt++ }
}
[IO.File]::WriteAllText($audit9, (($auditLines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))

$outputFiles = Join-Path $OutputRoot 'files'
$outputManifests = Join-Path $OutputRoot 'manifests'
if (Test-Path $outputFiles) { Remove-Item -Recurse -Force -LiteralPath $outputFiles }
if (Test-Path $outputManifests) { Remove-Item -Recurse -Force -LiteralPath $outputManifests }
New-Item -ItemType Directory -Force $outputFiles,$outputManifests | Out-Null

$classes = @{}
$classParents = @{}
$contentPaths = [System.Collections.Generic.HashSet[string]]::new()
foreach ($relative in ($assets.Keys | Sort-Object)) {
  $path = Destination $relative
  [void]$contentPaths.Add($path)
  $class = ClassName $path
  if (-not $classes.ContainsKey($class)) { $classes[$class] = [System.Collections.Generic.List[string]]::new() }
  if (-not $classParents.ContainsKey($class)) { $classParents[$class] = [System.Collections.Generic.HashSet[string]]::new() }
  [void]$classParents[$class].Add(([IO.Path]::GetDirectoryName($path).Replace('\','/')))
  $versions = $assets[$relative]
  $permission8 = $inventory['8'].permissions.$path
  $permission9 = $inventory['9'].permissions.$path
  $samePermission = (($permission8 | ConvertTo-Json -Compress) -eq ($permission9 | ConvertTo-Json -Compress))
  if ($versions.ContainsKey('8') -and $versions.ContainsKey('9')) {
    $sameContent = ((Get-FileHash $versions['8']).Hash -eq (Get-FileHash $versions['9']).Hash)
    if ($canonicalCommonAssets.ContainsKey($relative)) {
      $canonicalMajor = $canonicalCommonAssets[$relative]
      $target = Join-Path $outputFiles $relative
      New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
      Copy-Item -LiteralPath $versions[$canonicalMajor] -Destination $target
      $canonicalPermission = if ($canonicalMajor -eq '8') { $permission8 } else { $permission9 }
      $classes[$class].Add((FileResource $path "puppet:///modules/stigs/$relative" $canonicalPermission))
    } elseif ($sameContent) {
      $target = Join-Path $outputFiles $relative
      New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
      Copy-Item -LiteralPath $versions['8'] -Destination $target
      if ($samePermission) {
        $classes[$class].Add((FileResource $path "puppet:///modules/stigs/$relative" $permission8))
      } else {
        $r8 = FileResource $path "puppet:///modules/stigs/$relative" $permission8 '      '
        $r9 = FileResource $path "puppet:///modules/stigs/$relative" $permission9 '      '
        $classes[$class].Add("  case `$facts['os']['release']['major'] {`n    '8': {`n$r8`n    }`n    '9': {`n$r9`n    }`n  }")
      }
    } else {
      foreach ($major in @('8','9')) {
        $targetRelative = "$relative.$major"
        $target = Join-Path $outputFiles $targetRelative
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath $versions[$major] -Destination $target
      }
      $r8 = FileResource $path "puppet:///modules/stigs/$relative.8" $permission8 '      '
      $r9 = FileResource $path "puppet:///modules/stigs/$relative.9" $permission9 '      '
      $classes[$class].Add("  case `$facts['os']['release']['major'] {`n    '8': {`n$r8`n    }`n    '9': {`n$r9`n    }`n  }")
    }
  } else {
    $major = if ($versions.ContainsKey('8')) { '8' } else { '9' }
    $permission = if ($major -eq '8') { $permission8 } else { $permission9 }
    $target = Join-Path $outputFiles $relative
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $versions[$major] -Destination $target
    $resource = FileResource $path "puppet:///modules/stigs/$relative" $permission '      '
    $classes[$class].Add("  if `$facts['os']['release']['major'] == '$major' {`n$resource`n  }")
  }
}

foreach ($class in ($classes.Keys | Sort-Object)) {
  $directoryResources = [System.Collections.Generic.List[string]]::new()
  if ($classParents.ContainsKey($class)) {
    foreach ($parent in ($classParents[$class] | Sort-Object)) {
      $directoryResources.Add("  file { $(Quote "stig directory $parent"):`n    ensure => directory,`n    path   => $(Quote $parent),`n  }")
    }
  }
  $body = (@($directoryResources) + @($classes[$class])) -join "`n"
  [IO.File]::WriteAllText((Join-Path $outputManifests "$class.pp"), "$(ControlHeader $class)class stigs::$class {`n$body`n}`n", [Text.UTF8Encoding]::new($false))
}

$permissionsManifest = @"
class stigs::permissions (
  Hash[String[1], Struct[{
    Optional['owner'] => String[1],
    Optional['group'] => String[1],
    Optional['mode']  => Pattern[/^[0-7]{4}$/],
  }]] `$file_overrides = {},
) {
  `$account_file_permissions = {
    '/etc/group'    => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/group-'   => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/gshadow'  => { owner => 'root', group => 'root', mode => '0000' },
    '/etc/gshadow-' => { owner => 'root', group => 'root', mode => '0000' },
    '/etc/passwd'   => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/passwd-'  => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/shadow'   => { owner => 'root', group => 'root', mode => '0000' },
    '/etc/shadow-'  => { owner => 'root', group => 'root', mode => '0000' },
  }
  `$log_file_permissions = {
    '/var/log'          => { owner => 'root', group => 'root', mode => '0755' },
    '/var/log/messages' => { owner => 'root', group => 'root', mode => '0640' },
  }
  `$release_permissions = `$facts['os']['release']['major'] ? {
    '8'     => `$log_file_permissions,
    '9'     => `$account_file_permissions + `$log_file_permissions + {
      '/boot/grub2/grub.cfg' => { owner => 'root', group => 'root' },
    },
    '10'    => `$account_file_permissions + `$log_file_permissions,
    default => {},
  }

  if `$facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    `$unknown_files = `$file_overrides.keys - `$release_permissions.keys
    if `$unknown_files != [] {
      fail("stigs::permissions file_overrides contains paths without defaults for this OS: `${unknown_files}")
    }

    `$release_permissions.each |String `$file_path, Hash `$default_attributes| {
      `$override_attributes = `$file_overrides[`$file_path] ? {
        undef   => {},
        default => `$file_overrides[`$file_path],
      }
      `$effective_attributes = `$default_attributes + `$override_attributes
      file { "stig permissions `${file_path}":
        path => `$file_path,
        *    => `$effective_attributes,
      }
    }
  }
}
"@
[IO.File]::WriteAllText((Join-Path $outputManifests 'permissions.pp'), "$(ControlHeader 'permissions')$permissionsManifest", [Text.UTF8Encoding]::new($false))

# Packages common to both releases are declared once; differences are selected by fact.
$packageNames = @($inventory['8'].packages.PSObject.Properties.Name) + @($inventory['9'].packages.PSObject.Properties.Name) | Sort-Object -Unique
$commonPackages = [System.Collections.Generic.List[string]]::new()
$specificPackages = @{ '8'=[System.Collections.Generic.List[string]]::new(); '9'=[System.Collections.Generic.List[string]]::new() }
foreach ($name in $packageNames) {
  $v8 = $inventory['8'].packages.$name
  $v9 = $inventory['9'].packages.$name
  if ($v8 -and $v9 -and $v8 -eq $v9) { $commonPackages.Add("    $(Quote $name) => { ensure => $v8 },") }
  else {
    if ($v8) { $specificPackages['8'].Add("        $(Quote $name) => { ensure => $v8 },") }
    if ($v9) { $specificPackages['9'].Add("        $(Quote $name) => { ensure => $v9 },") }
  }
}
$rhel10Packages = [ordered]@{
  'audispd-plugins' = 'installed'
  'chrony' = 'installed'
  'cronie' = 'installed'
  'firewalld' = 'installed'
  'gdm' = 'absent'
  'gnutls-utils' = 'installed'
  'libreswan' = 'installed'
  'nfs-utils' = 'absent'
  'nss-tools' = 'installed'
  'openssh-clients' = 'installed'
  'openssh-server' = 'installed'
  'pcsc-lite' = 'installed'
  'pcsc-lite-ccid' = 'installed'
  'pkcs11-provider' = 'installed'
  'policycoreutils-python-utils' = 'installed'
  's-nail' = 'installed'
  'subscription-manager' = 'installed'
  'sudo' = 'installed'
  'tftp' = 'absent'
  'unbound' = 'absent'
  'vsftpd' = 'absent'
}
$rhel10PackageLines = foreach ($entry in $rhel10Packages.GetEnumerator()) {
  "        $(Quote $entry.Key) => { ensure => $($entry.Value) },"
}
$packagesManifest = @"
class stigs::packages (
  Hash[String, Struct[{
    'ensure' => Enum['installed', 'absent'],
  }]] `$package_overrides = {},
) {
  `$common_packages = {
$($commonPackages -join "`n")
  }
  `$release_packages = `$facts['os']['release']['major'] ? {
    '8' => {
$($specificPackages['8'] -join "`n")
    },
    '9' => {
$($specificPackages['9'] -join "`n")
    },
    '10' => {
$($rhel10PackageLines -join "`n")
    },
    default => {},
  }
  if `$facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    `$default_packages = `$common_packages + `$release_packages
    `$unknown_packages = `$package_overrides.keys - `$default_packages.keys
    if `$unknown_packages != [] {
      fail("stigs::packages package_overrides contains packages without defaults for this OS: `${unknown_packages}")
    }
    `$default_packages.each |String `$package_name, Hash `$default_attributes| {
      `$override_attributes = `$package_overrides[`$package_name] ? {
        undef   => {},
        default => `$package_overrides[`$package_name],
      }
      `$effective_attributes = `$default_attributes + `$override_attributes
      package { `$package_name: * => `$effective_attributes }
    }
  }
}
"@
[IO.File]::WriteAllText((Join-Path $outputManifests 'packages.pp'), "$(ControlHeader 'packages')$packagesManifest", [Text.UTF8Encoding]::new($false))

# Service state is normalized into a common map and release-specific map.
$serviceNames = @($inventory['8'].services.PSObject.Properties.Name) + @($inventory['9'].services.PSObject.Properties.Name) | Sort-Object -Unique
$commonServices = [System.Collections.Generic.List[string]]::new()
$specificServices = @{ '8'=[System.Collections.Generic.List[string]]::new(); '9'=[System.Collections.Generic.List[string]]::new() }
function ServiceEntry([string]$name, [object]$s, [string]$indent) {
  $pairs = [System.Collections.Generic.List[string]]::new()
  if ($s.ensure) { $pairs.Add("ensure => $($s.ensure)") }
  if ($null -ne $s.enable) { $pairs.Add("enable => $(([bool]$s.enable).ToString().ToLower())") }
  if ($s.masked) { $pairs.Add('masked => true') }
  return "$indent$(Quote $name) => { $($pairs -join ', ') },"
}
foreach ($name in $serviceNames) {
  $s8 = $inventory['8'].services.$name
  $s9 = $inventory['9'].services.$name
  if ($s8 -and $s9 -and (($s8 | ConvertTo-Json -Compress) -eq ($s9 | ConvertTo-Json -Compress))) { $commonServices.Add((ServiceEntry $name $s8 '    ')) }
  else {
    if ($s8) { $specificServices['8'].Add((ServiceEntry $name $s8 '        ')) }
    if ($s9) { $specificServices['9'].Add((ServiceEntry $name $s9 '        ')) }
  }
}
$rhel10Services = [ordered]@{
  'autofs.service' = [pscustomobject]@{ ensure = $null; enable = $false; masked = $true }
  'chronyd.service' = [pscustomobject]@{ ensure = 'running'; enable = $true; masked = $false }
  'debug-shell.service' = [pscustomobject]@{ ensure = $null; enable = $false; masked = $true }
  'kdump.service' = [pscustomobject]@{ ensure = $null; enable = $false; masked = $true }
  'pcscd.socket' = [pscustomobject]@{ ensure = 'running'; enable = $true; masked = $false }
  'systemd-coredump.socket' = [pscustomobject]@{ ensure = $null; enable = $false; masked = $true }
  'systemd-journald.service' = [pscustomobject]@{ ensure = 'running'; enable = $null; masked = $false }
}
$rhel10ServiceLines = foreach ($entry in $rhel10Services.GetEnumerator()) {
  ServiceEntry $entry.Key $entry.Value '        '
}
$servicesManifest = @"
class stigs::services {
  `$common_services = {
$($commonServices -join "`n")
  }
  `$release_services = `$facts['os']['release']['major'] ? {
    '8' => {
$($specificServices['8'] -join "`n")
    },
    '9' => {
$($specificServices['9'] -join "`n")
    },
    '10' => {
$($rhel10ServiceLines -join "`n")
    },
    default => {},
  }
  if `$facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    (`$common_services + `$release_services).each |String `$service_name, Hash `$attributes| {
      if `$attributes['masked'] {
        exec { "mask `${service_name}":
          command => "/usr/bin/systemctl mask --now `${service_name}",
          unless  => "/usr/bin/systemctl is-enabled `${service_name} | /usr/bin/grep -qx masked",
        }
      } else {
        service { `$service_name: * => `$attributes }
      }
    }
    exec { 'disable wireless radios':
      command => '/usr/bin/nmcli radio all off',
      unless  => '/usr/bin/test x`$(/usr/bin/nmcli -t -f WIFI,WWAN general) = xdisabled:disabled',
      onlyif  => '/usr/bin/test -x /usr/bin/nmcli',
    }
  }
  if `$facts['os']['release']['major'] == '9' {
    exec { 'set inactive account default':
      command => '/usr/sbin/useradd -D -f 35',
      unless  => "/usr/sbin/useradd -D | /usr/bin/grep -qx 'INACTIVE=35'",
    }
  }
  exec { 'reload audit rules':
    command     => '/usr/sbin/augenrules --load',
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/augenrules',
  }
  exec { 'reload sysctl settings':
    command     => '/usr/sbin/sysctl --system',
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/sysctl',
  }
  exec { 'update dconf database':
    command     => '/usr/bin/dconf update',
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/bin/dconf',
  }
  exec { 'systemd daemon reload': command => '/usr/bin/systemctl daemon-reload', refreshonly => true }
  exec { 'reload rsyslog configuration':
    command     => "/bin/sh -c '/usr/sbin/rsyslogd -N1 && /usr/bin/systemctl try-reload-or-restart rsyslog.service'",
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/rsyslogd',
  }
  exec { 'reload sshd configuration':
    command     => "/bin/sh -c '/usr/sbin/sshd -t && /usr/bin/systemctl reload sshd.service'",
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/sshd',
  }
  exec { 'validate and restart sssd':
    command     => "/bin/sh -c '/usr/sbin/sssctl config-check && /usr/bin/systemctl try-restart sssd.service'",
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/sssctl',
  }
}
"@
[IO.File]::WriteAllText((Join-Path $outputManifests 'services.pp'), "$(ControlHeader 'services')$servicesManifest", [Text.UTF8Encoding]::new($false))

$includes = $classes.Keys | Sort-Object | ForEach-Object { "  include stigs::$_" }
$includes += '  include stigs::permissions', '  include stigs::packages', '  include stigs::services'
$aggregateHeader = "# DISA STIG vulnerability IDs: none directly; this class aggregates the`n# functional STIG classes listed below.`n"
[IO.File]::WriteAllText((Join-Path $outputManifests 'main.pp'), "${aggregateHeader}class stigs::main {`n  if `$facts['os']['family'] != 'RedHat' or `$facts['os']['release']['major'] !~ /^(8|9|10)$/ {`n    fail('stigs supports only RHEL 8, RHEL 9, and RHEL 10')`n  }`n$($includes -join "`n")`n`n  Class['stigs::packages'] -> Class['stigs::services']`n}`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $outputManifests 'init.pp'), "# DISA STIG vulnerability IDs: none directly; compatibility entry point.`nclass stigs inherits stigs::main { }`n", [Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'format_puppet_arrows.ps1') -Path $outputManifests
Write-Host "Merged $($assets.Count) file paths into $($classes.Count) functional manifests."
