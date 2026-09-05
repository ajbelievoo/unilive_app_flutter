$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$libPath = Join-Path $repoRoot 'lib'

if (-not (Test-Path -LiteralPath $libPath)) {
  throw "lib folder not found: $libPath"
}

$files = Get-ChildItem -LiteralPath $libPath -Recurse -File -Filter '*.dart'

$changed = 0
foreach ($file in $files) {
  $raw = Get-Content -LiteralPath $file.FullName -Raw
  $new = $raw -replace '(?m)^library;\s*\r?\n(\r?\n)?', ''
  if ($new -ne $raw) {
    Set-Content -LiteralPath $file.FullName -Value $new -Encoding utf8
    $changed++
    Write-Host "Fixed: $($file.FullName)"
  }
}

Write-Host "Done. Updated $changed file(s)."
