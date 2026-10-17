param(
  [string]$RoleRoot = (Join-Path $PSScriptRoot '..\ansible\U_RHEL_8_V2R8_STIG_Ansible\rhel8STIG-ansible\roles\rhel8STIG'),
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\modules\stigs')
)

$ErrorActionPreference = 'Stop'
$defaultsPath = Join-Path $RoleRoot 'defaults\main.yml'
$tasksPath = Join-Path $RoleRoot 'tasks\main.yml'

function Read-Defaults([string]$Path) {
  $result = @{}
  $lines = Get-Content -LiteralPath $Path
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^([A-Za-z0-9_]+):\s*(.*)$') {
      $key = $Matches[1]
      $value = $Matches[2]
      if ($value -eq '|') {
        $block = [System.Collections.Generic.List[string]]::new()
        $i++
        while ($i -lt $lines.Count -and ($lines[$i] -match '^  ' -or $lines[$i] -eq '')) {
          $block.Add(($lines[$i] -replace '^  ', ''))
          $i++
        }
        $i--
        $result[$key] = ($block -join "`n").TrimEnd() + "`n"
      } else {
        $value = $value.Trim()
        if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
          $value = $value.Substring(1, $value.Length - 2)
        }
        $result[$key] = $value
      }
    }
  }
  return $result
}

function Resolve-Value([string]$Value, [hashtable]$Defaults) {
  if ($null -eq $Value) { return $null }
  $value = $Value.Trim().Trim('"').Trim("'")
  if ($value -match '^\{\{\s*([A-Za-z0-9_]+)\s*\}\}$') {
    if (-not $Defaults.ContainsKey($Matches[1])) { throw "Missing default $($Matches[1])" }
    return [string]$Defaults[$Matches[1]]
  }
  return $value
}

function Get-Field([string]$Block, [string]$Name, [hashtable]$Defaults) {
  if ($Block -match "(?m)^    $([regex]::Escape($Name)):\s*(.+)$") {
    return Resolve-Value $Matches[1] $Defaults
  }
  return $null
}

function Puppet-Quote([string]$Value) {
  return "'" + $Value.Replace('\', '\\').Replace("'", "\\'") + "'"
}

function Class-ForPath([string]$Path) {
  if ($Path.StartsWith('/etc/')) {
    $relative = $Path.Substring(5)
    if ($relative.Contains('/')) { return ((($relative.Split('/')[0]) -replace '[^a-zA-Z0-9_]', '_').ToLower()) }
    return 'etc'
  }
  if ($Path.StartsWith('/usr/lib/systemd/system/')) { return 'systemd_units' }
  if ($Path.StartsWith('/boot/')) { return 'boot' }
  if ($Path.StartsWith('/var/')) { return 'var' }
  return 'system'
}

$defaults = Read-Defaults $defaultsPath
$text = Get-Content -Raw -LiteralPath $tasksPath
$blocks = [regex]::Split($text, '(?m)(?=^- name:)') | Where-Object { $_ -match '^- name:' }
$files = @{}
$inis = @{}
$packages = @{}
$services = @{}
$sysctls = @{}
$permissions = @{}
$controlMap = @{}

function Add-Control([string]$ClassName, [string]$Block) {
  if ($Block -notmatch 'stigrule_(\d+)') { return }
  $vulnId = "V-$($Matches[1])"
  if (-not $controlMap.ContainsKey($ClassName)) { $controlMap[$ClassName] = [System.Collections.Generic.HashSet[string]]::new() }
  [void]$controlMap[$ClassName].Add($vulnId)
}

foreach ($block in $blocks) {
  if ($block -match '(?m)^  lineinfile:$') {
    $path = Get-Field $block 'path' $defaults
    $line = Get-Field $block 'line' $defaults
    if ($path -and $line) {
      Add-Control (Class-ForPath $path) $block
      if (-not $files.ContainsKey($path)) { $files[$path] = [System.Collections.Generic.List[string]]::new() }
      if (-not $files[$path].Contains($line)) { $files[$path].Add($line) }
    }
  } elseif ($block -match '(?m)^  ini_file:$') {
    $path = Get-Field $block 'path' $defaults
    $section = Get-Field $block 'section' $defaults
    $option = Get-Field $block 'option' $defaults
    $value = Get-Field $block 'value' $defaults
    if ($path -and $section -and $option) {
      Add-Control (Class-ForPath $path) $block
      if (-not $inis.ContainsKey($path)) { $inis[$path] = [ordered]@{} }
      if (-not $inis[$path].Contains($section)) { $inis[$path][$section] = [ordered]@{} }
      $inis[$path][$section][$option] = $value
    }
  } elseif ($block -match '(?m)^  copy:$') {
    $path = Get-Field $block 'dest' $defaults
    $content = Get-Field $block 'content' $defaults
    if ($path -and $content) {
      Add-Control (Class-ForPath $path) $block
      $list = [System.Collections.Generic.List[string]]::new()
      $list.Add($content.TrimEnd())
      $files[$path] = $list
    }
  } elseif ($block -match '(?m)^  file:$') {
    $path = Get-Field $block 'dest' $defaults
    if (-not $path) { $path = Get-Field $block 'path' $defaults }
    if ($path) {
      Add-Control (Class-ForPath $path) $block
      if (-not $permissions.ContainsKey($path)) { $permissions[$path] = [ordered]@{} }
      foreach ($attribute in @('owner', 'group', 'mode')) {
        $attributeValue = Get-Field $block $attribute $defaults
        if ($attributeValue) { $permissions[$path][$attribute] = $attributeValue }
      }
    }
  } elseif ($block -match '(?m)^  yum:$') {
    $name = Get-Field $block 'name' $defaults
    $state = Get-Field $block 'state' $defaults
    if ($name) {
      Add-Control 'packages' $block
      $packages[$name] = if ($state -in @('removed','absent')) { 'absent' } else { 'installed' }
    }
  } elseif ($block -match '(?m)^  (service|systemd_service):$') {
    $name = Get-Field $block 'name' $defaults
    if ($name) {
      Add-Control 'services' $block
      if (-not $services.ContainsKey($name)) { $services[$name] = [ordered]@{ ensure = $null; enable = $null; masked = $false } }
      $state = Get-Field $block 'state' $defaults
      $enabled = Get-Field $block 'enabled' $defaults
      $masked = Get-Field $block 'masked' $defaults
      if ($state) { $services[$name].ensure = if ($state -eq 'started') { 'running' } else { 'stopped' } }
      if ($enabled) { $services[$name].enable = $enabled -match '^(yes|true)$' }
      if ($masked -match '^(yes|true)$') { $services[$name].masked = $true }
    }
  } elseif ($block -match '(?m)^  sysctl:$') {
    $name = Get-Field $block 'name' $defaults
    $value = Get-Field $block 'value' $defaults
    $path = Get-Field $block 'sysctl_file' $defaults
    if (-not $path) { $path = '/etc/sysctl.d/99-rhel8-stig.conf' }
    if ($name) {
      Add-Control 'sysctl_d' $block
      if (-not $sysctls.ContainsKey($path)) { $sysctls[$path] = [ordered]@{} }
      $sysctls[$path][$name] = $value
    }
  } elseif ($block -match '(?m)^  shell:') {
    Add-Control 'services' $block
  }
}

foreach ($path in $inis.Keys) {
  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($section in $inis[$path].Keys) {
    $lines.Add("[$section]")
    foreach ($option in $inis[$path][$section].Keys) { $lines.Add("$option=$($inis[$path][$section][$option])") }
    $lines.Add('')
  }
  $files[$path] = $lines
}
foreach ($path in $sysctls.Keys) {
  if (-not $files.ContainsKey($path)) { $files[$path] = [System.Collections.Generic.List[string]]::new() }
  foreach ($name in $sysctls[$path].Keys) {
    $line = "$name = $($sysctls[$path][$name])"
    if (-not $files[$path].Contains($line)) { $files[$path].Add($line) }
  }
}

New-Item -ItemType Directory -Force -Path (Join-Path $OutputRoot 'files'), (Join-Path $OutputRoot 'manifests') | Out-Null
$classResources = @{}
$classParents = @{}
foreach ($path in ($files.Keys | Sort-Object)) {
  $class = Class-ForPath $path
  if (-not $classResources.ContainsKey($class)) { $classResources[$class] = [System.Collections.Generic.List[string]]::new() }
  if (-not $classParents.ContainsKey($class)) { $classParents[$class] = [System.Collections.Generic.HashSet[string]]::new() }
  $relative = $path.TrimStart('/')
  if ($path.StartsWith('/etc/')) {
    $etcRelative = $path.Substring(5)
    $sourceRelative = if ($etcRelative.Contains('/')) { $etcRelative } else { "etc/$etcRelative" }
  } else { $sourceRelative = $relative }
  $asset = Join-Path (Join-Path $OutputRoot 'files') ($sourceRelative.Replace('/', [IO.Path]::DirectorySeparatorChar))
  New-Item -ItemType Directory -Force -Path (Split-Path $asset) | Out-Null
  $content = (($files[$path] -join "`n").TrimEnd() + "`n")
  [IO.File]::WriteAllText($asset, $content, [Text.UTF8Encoding]::new($false))
  $title = "stig $path"
  $notify = switch -Regex ($path) {
    '^/etc/ssh/' { ",`n    notify  => Service['sshd.service']"; break }
    '^/etc/audit/' { ",`n    notify  => Exec['reload audit rules']"; break }
    '^/etc/rsyslog' { ",`n    notify  => Service['rsyslog.service']"; break }
    '^/etc/sysctl.d/' { ",`n    notify  => Exec['reload sysctl settings']"; break }
    '^/etc/dconf/' { ",`n    notify  => Exec['update dconf database']"; break }
    '^/(etc|usr/lib)/systemd/' { ",`n    notify  => Exec['systemd daemon reload']"; break }
    default { '' }
  }
  $resource = @"
  file { $(Puppet-Quote $title):
    ensure  => file,
    path    => $(Puppet-Quote $path),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source       => stigs::source_candidates($(Puppet-Quote "puppet:///modules/stigs/$sourceRelative")),
    sourceselect => 'first',
    require      => File[$(Puppet-Quote (Split-Path $path -Parent).Replace('\','/'))]$notify,
  }
"@
  $parent = (Split-Path $path -Parent).Replace('\','/')
  [void]$classParents[$class].Add($parent)
  $classResources[$class].Add($resource)
}

foreach ($class in ($classResources.Keys | Sort-Object)) {
  $parentResources = $classParents[$class] | Sort-Object | ForEach-Object { "  file { $(Puppet-Quote $_): ensure => directory }" }
  $body = (@($parentResources) + @($classResources[$class]) -join "`n")
  $manifest = "class stigs::$class {`n$body`n}`n"
  [IO.File]::WriteAllText((Join-Path $OutputRoot "manifests\$class.pp"), $manifest, [Text.UTF8Encoding]::new($false))
}

$packageLines = foreach ($name in ($packages.Keys | Sort-Object)) {
  "    $(Puppet-Quote $name) => { ensure => $($packages[$name]) },"
}
$packagesManifest = @"
class stigs::packages (
  Hash[String, Struct[{
    'ensure' => Enum['installed', 'absent'],
  }]] `$package_overrides = {},
) {
  `$packages = {
$($packageLines -join "`n")
  }
  `$unknown_packages = `$package_overrides.keys - `$packages.keys
  if `$unknown_packages != [] {
    fail("stigs::packages package_overrides contains packages without defaults for this OS: `${unknown_packages}")
  }
  `$packages.each |String `$package_name, Hash `$default_attributes| {
    `$override_attributes = `$package_overrides[`$package_name] ? {
      undef   => {},
      default => `$package_overrides[`$package_name],
    }
    `$effective_attributes = `$default_attributes + `$override_attributes
    package { `$package_name: * => `$effective_attributes }
  }
}
"@
[IO.File]::WriteAllText((Join-Path $OutputRoot 'manifests\packages.pp'), $packagesManifest, [Text.UTF8Encoding]::new($false))

$serviceLines = [System.Collections.Generic.List[string]]::new()
foreach ($name in ($services.Keys | Sort-Object)) {
  $s = $services[$name]
  if ($s.masked) {
    $serviceLines.Add("  exec { $(Puppet-Quote "mask $name"):`n    command => $(Puppet-Quote "/usr/bin/systemctl mask --now $name"),`n    unless  => $(Puppet-Quote "/usr/bin/systemctl is-enabled $name | /usr/bin/grep -qx masked"),`n  }")
  } else {
    $attrs = @()
    if ($null -ne $s.ensure) { $attrs += "ensure => $($s.ensure)" }
    if ($null -ne $s.enable) { $attrs += "enable => $($s.enable.ToString().ToLower())" }
    $serviceLines.Add("  service { $(Puppet-Quote $name): $($attrs -join ', ') }")
  }
}
$serviceLines.Add("  exec { 'disable wireless radios':`n    command => '/usr/bin/nmcli radio wifi off',`n    unless  => '/usr/bin/test x`$(/usr/bin/nmcli -t -f WIFI general) = xdisabled',`n    onlyif  => '/usr/bin/test -x /usr/bin/nmcli',`n  }")
$serviceLines.Add("  exec { 'reload audit rules':`n    command     => '/usr/sbin/augenrules --load',`n    refreshonly => true,`n  }")
$serviceLines.Add("  exec { 'reload sysctl settings':`n    command     => '/usr/sbin/sysctl --system',`n    refreshonly => true,`n  }")
$serviceLines.Add("  exec { 'update dconf database':`n    command     => '/usr/bin/dconf update',`n    refreshonly => true,`n  }")
$serviceLines.Add("  exec { 'systemd daemon reload':`n    command     => '/usr/bin/systemctl daemon-reload',`n    refreshonly => true,`n  }")
[IO.File]::WriteAllText((Join-Path $OutputRoot 'manifests\services.pp'), "class stigs::services {`n$($serviceLines -join "`n")`n}`n", [Text.UTF8Encoding]::new($false))

$includes = @($classResources.Keys | Sort-Object | ForEach-Object { "  include stigs::$_" })
$includes += '  include stigs::packages', '  include stigs::services'
[IO.File]::WriteAllText((Join-Path $OutputRoot 'manifests\main.pp'), "class stigs::main {`n$($includes -join "`n")`n}`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $OutputRoot 'manifests\init.pp'), "class stigs inherits stigs::main { }`n", [Text.UTF8Encoding]::new($false))

& (Join-Path $PSScriptRoot 'format_puppet_arrows.ps1') -Path (Join-Path $OutputRoot 'manifests')

$inventory = [ordered]@{
  packages = $packages
  services = $services
  permissions = $permissions
  control_map = $controlMap
}
[IO.File]::WriteAllText((Join-Path $OutputRoot 'generated-inventory.json'), ($inventory | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

Write-Host "Generated $($files.Count) complete file assets, $($packages.Count) packages, and $($services.Count) services."
