$out = & 'C:\flutter_new\flutter\bin\flutter.bat' analyze --no-pub lib 2>&1
$errors = $out | Where-Object { $_ -match '^\s+error\s+- ' }
Write-Host "=== ERRORS ONLY ($($errors.Count) found) ==="
foreach ($e in $errors) { Write-Host $e }
Write-Host "=== END ==="
