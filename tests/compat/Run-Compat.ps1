param(
  [string]$BinaryPath,
  [ValidateSet('compat','toolbar','rml')][string]$Suite = 'compat'
)
$ErrorActionPreference = 'Stop'
$clientRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $BinaryPath) { $BinaryPath = Join-Path $clientRoot 'otclient_dx_x64.exe' }
$binary = (Resolve-Path -LiteralPath $BinaryPath).Path
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('astra-rml-compat-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$bootstrap = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bootstrap.lua') -Raw
$bootstrap = $bootstrap.Replace('APP_NAME = "astra_rml_compat_test"', ('APP_NAME = "astra_rml_compat_test_' + $Suite + '"'))
[IO.File]::WriteAllText((Join-Path $testDirectory 'init.lua'), $bootstrap, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot ($Suite + '_test.lua')) -Destination (Join-Path $testDirectory 'test.lua')
Copy-Item -LiteralPath (Join-Path $clientRoot 'init.lua') -Destination (Join-Path $testDirectory 'production-init.lua')
if (Test-Path -LiteralPath (Join-Path $clientRoot 'packet.log')) {
  Copy-Item -LiteralPath (Join-Path $clientRoot 'packet.log') -Destination (Join-Path $testDirectory 'captured-packet.log')
}
foreach ($resourceName in @('data','modules','mods','layouts','tests')) {
  New-Item -ItemType Junction -Path (Join-Path $testDirectory $resourceName) -Target (Join-Path $clientRoot $resourceName) | Out-Null
}
$stdout = Join-Path $testDirectory 'stdout.log'
$stderr = Join-Path $testDirectory 'stderr.log'
$process = Start-Process -FilePath $binary -ArgumentList '--test' -WorkingDirectory $testDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (-not $process.WaitForExit(45000)) {
  Stop-Process -Id $process.Id
  throw "Compatibility test timed out. Logs: $testDirectory"
}
$process.Refresh()
$result = Get-Content -LiteralPath $stdout -Raw
Write-Output $result
Write-Output "Compatibility test artifacts: $testDirectory"
$successMarker = @{compat='ASTRA_RML_COMPAT_PASS:';toolbar='ASTRA_TOOLBAR_PASS:';rml='ASTRA_RML_SCREENS_PASS:'}[$Suite]
if ($process.ExitCode -ne 0 -or $result -notmatch $successMarker) {
  Get-Content -LiteralPath $stderr
  throw "Compatibility test failed ($($process.ExitCode)). Logs: $testDirectory"
}
