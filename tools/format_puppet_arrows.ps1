param(
  [string[]]$Path = @((Join-Path $PSScriptRoot '..\modules\stigs'))
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$files = [System.Collections.Generic.List[IO.FileInfo]]::new()

foreach ($item in $Path) {
  $resolved = [IO.Path]::GetFullPath($item)
  if (-not $resolved.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path must remain inside the repository: $resolved"
  }
  if (Test-Path -LiteralPath $resolved -PathType Container) {
    foreach ($file in (Get-ChildItem -LiteralPath $resolved -Recurse -File -Filter '*.pp')) {
      $files.Add($file)
    }
  } elseif (Test-Path -LiteralPath $resolved -PathType Leaf) {
    if ([IO.Path]::GetExtension($resolved) -ne '.pp') {
      throw "Puppet manifest must have a .pp extension: $resolved"
    }
    $files.Add((Get-Item -LiteralPath $resolved))
  } else {
    throw "Path does not exist: $resolved"
  }
}

$changed = 0
foreach ($file in @($files | Sort-Object FullName -Unique)) {
  $lines = [IO.File]::ReadAllLines($file.FullName)
  $original = [string[]]$lines.Clone()
  $processedBlocks = [System.Collections.Generic.HashSet[string]]::new()
  $index = 0

  while ($index -lt $lines.Count) {
    if ($lines[$index] -notmatch '^(\s*)([^#].*?)(\s*)=>(.*)$') {
      $index++
      continue
    }

    $indent = $Matches[1]
    $indentWidth = $indent.Length
    $blockStart = $index
    while ($blockStart -gt 0) {
      $previous = $lines[$blockStart - 1]
      if ($previous.Trim().Length -gt 0 -and $previous -match '^(\s*)' -and $Matches[1].Length -lt $indentWidth) { break }
      $blockStart--
    }
    $blockEnd = $index
    while ($blockEnd + 1 -lt $lines.Count) {
      $following = $lines[$blockEnd + 1]
      if ($following.Trim().Length -gt 0 -and $following -match '^(\s*)' -and $Matches[1].Length -lt $indentWidth) { break }
      $blockEnd++
    }
    $blockKey = "${indentWidth}:${blockStart}:${blockEnd}"
    if (-not $processedBlocks.Add($blockKey)) {
      $index++
      continue
    }

    $run = [System.Collections.Generic.List[int]]::new()
    $leftSides = [System.Collections.Generic.List[string]]::new()
    $rightSides = [System.Collections.Generic.List[string]]::new()
    for ($cursor = $blockStart; $cursor -le $blockEnd; $cursor++) {
      if ($lines[$cursor] -match '^(\s*)([^#].*?)(\s*)=>(.*)$' -and $Matches[1] -eq $indent) {
        $run.Add($cursor)
        $leftSides.Add($Matches[2].TrimEnd())
        $rightSides.Add($Matches[4])
      }
    }

    $width = ($leftSides | ForEach-Object Length | Measure-Object -Maximum).Maximum
    for ($offset = 0; $offset -lt $run.Count; $offset++) {
      $lines[$run[$offset]] = $indent + $leftSides[$offset].PadRight($width + 1) + '=>' + $rightSides[$offset]
    }
    $index++
  }

  if ((Compare-Object $original $lines -SyncWindow 0).Count -gt 0) {
    [IO.File]::WriteAllLines($file.FullName, $lines, [Text.UTF8Encoding]::new($false))
    $changed++
  }
}

Write-Host "Aligned Puppet hash rockets in $changed file(s)."
