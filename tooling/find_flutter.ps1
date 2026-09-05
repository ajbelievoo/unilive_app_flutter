$paths = @(
  'C:\flutter\bin\flutter.bat',
  'C:\src\flutter\bin\flutter.bat',
  'C:\dev\flutter\bin\flutter.bat',
  'D:\flutter\bin\flutter.bat',
  'E:\flutter\bin\flutter.bat',
  "C:\Users\$env:USERNAME\flutter\bin\flutter.bat",
  'C:\tools\flutter\bin\flutter.bat',
  "C:\Users\$env:USERNAME\dev\flutter\bin\flutter.bat",
  "C:\Users\$env:USERNAME\AppData\Local\flutter\bin\flutter.bat",
  'D:\dev\flutter\bin\flutter.bat',
  'E:\dev\flutter\bin\flutter.bat',
  'E:\uni\flutter\bin\flutter.bat'
)

$found = $false
foreach ($p in $paths) {
  if (Test-Path -LiteralPath $p) {
    Write-Host "FOUND: $p"
    $found = $true
  }
}

if (-not $found) {
  Write-Host "NOT_FOUND in common locations. Searching..."
  Get-ChildItem -Path 'C:\','D:\','E:\' -Filter 'flutter.bat' -Recurse -ErrorAction SilentlyContinue -Depth 5 | Select-Object -First 3 -ExpandProperty FullName
}
