$ErrorActionPreference = 'Stop'
$pidPath = Join-Path $PSScriptRoot '..\.local\account-service.pid'
if (-not (Test-Path -LiteralPath $pidPath)) { Write-Output 'Account service is not running from this launcher.'; return }
$accountServicePid = [int](Get-Content -LiteralPath $pidPath)
$serviceProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $accountServicePid"
if ($null -eq $serviceProcess) { Remove-Item -LiteralPath $pidPath; Write-Output 'Account service has already stopped.'; return }
$entryPoint = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'server\start-accounts.cjs')
$isThisProject = $serviceProcess.CommandLine -and $serviceProcess.CommandLine.ToLowerInvariant().Contains($entryPoint.ToLowerInvariant())
$legacyLauncher = $serviceProcess.CommandLine -match '\sserver/start-accounts\.cjs\s*$'
if ($serviceProcess.Name -ne 'node.exe' -or (-not $isThisProject -and -not $legacyLauncher)) { throw 'The saved process is no longer this project account service. No process was stopped.' }
$workerPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'ai\worker.py').ToLowerInvariant()
Get-CimInstance Win32_Process -Filter "ParentProcessId = $accountServicePid" | Where-Object { $_.Name -eq 'python.exe' -and $_.CommandLine -and $_.CommandLine.ToLowerInvariant().Contains($workerPath) } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
Stop-Process -Id $accountServicePid
Remove-Item -LiteralPath $pidPath
Write-Output 'Account service stopped.'
