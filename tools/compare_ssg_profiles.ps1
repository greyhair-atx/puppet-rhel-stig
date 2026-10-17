param(
  [string]$DatastreamRoot = (Join-Path $PSScriptRoot '..\.ps_sandbox\ssg_datastreams')
)

$ErrorActionPreference = 'Stop'
$profileId = 'xccdf_org.ssgproject.content_profile_stig'
$streams = @{}

foreach ($major in @('8', '9', '10')) {
  $path = Join-Path $DatastreamRoot "ssg-rhel${major}-ds.xml"
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing RHEL $major datastream: $path"
  }

  $document = [xml]::new()
  $document.PreserveWhitespace = $false
  $document.Load((Resolve-Path -LiteralPath $path))
  $profile = $document.SelectSingleNode("//*[local-name()='Profile' and @id='$profileId']")
  if (-not $profile) {
    throw "Profile $profileId was not found in $path"
  }

  $rules = @{}
  foreach ($selection in $profile.SelectNodes("./*[local-name()='select' and @selected='true']")) {
    $rule = $document.SelectSingleNode("//*[local-name()='Rule' and @id='$($selection.idref)']")
    if (-not $rule) { continue }
    $name = $selection.idref -replace '^xccdf_org\.ssgproject\.content_rule_', ''
    $fixTypes = @($rule.SelectNodes("./*[local-name()='fix']") | ForEach-Object {
      $_.system -replace '^urn:xccdf:fix:script:', ''
    } | Sort-Object -Unique)
    $titleNode = $rule.SelectSingleNode("./*[local-name()='title']")
    $rules[$name] = [pscustomobject]@{
      title     = if ($titleNode) { $titleNode.InnerText.Trim() } else { '' }
      fix_types = $fixTypes
    }
  }

  $refinements = @{}
  foreach ($refinement in $profile.SelectNodes("./*[local-name()='refine-value']")) {
    $name = $refinement.idref -replace '^xccdf_org\.ssgproject\.content_value_', ''
    $refinements[$name] = $refinement.selector
  }

  $streams[$major] = [pscustomobject]@{
    path        = (Resolve-Path -LiteralPath $path).Path
    sha256      = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    rules       = $rules
    refinements = $refinements
  }

  $bashCount = @($rules.Values | Where-Object { $_.fix_types -contains 'sh' }).Count
  $puppetCount = @($rules.Values | Where-Object { $_.fix_types -contains 'puppet' }).Count
  "RHEL ${major}: selected=$($rules.Count) bash_fixes=$bashCount puppet_fixes=$puppetCount sha256=$($streams[$major].sha256)"
  $document = $null
  [GC]::Collect()
}

foreach ($major in @('8', '9', '10')) {
  $otherMajors = @('8', '9', '10') | Where-Object { $_ -ne $major }
  $unique = @($streams[$major].rules.Keys | Where-Object {
    -not $streams[$otherMajors[0]].rules.ContainsKey($_) -and
    -not $streams[$otherMajors[1]].rules.ContainsKey($_)
  } | Sort-Object)
  ""
  "Rules only selected by the RHEL ${major} profile ($($unique.Count)):"
  foreach ($name in $unique) {
    "  $name :: $($streams[$major].rules[$name].title)"
  }
}
