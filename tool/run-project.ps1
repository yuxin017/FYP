param([switch]$Restart, [switch]$NoLogin)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$launchMutex = $null
$ownsLaunch = $false
try {
    if ($Restart) { & (Join-Path $PSScriptRoot 'stop-project.ps1') }
    $launchMutex = New-Object System.Threading.Mutex($false, ('Local\ThemeParkFYP-launch-' + (Get-FypWorkspaceId)))
    try { $ownsLaunch = $launchMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $ownsLaunch = $true }
    $probeMessages = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check-web-server.ps1')
    $webState = $LASTEXITCODE
    if (-not $ownsLaunch -and $webState -ne 2) {
        Write-Host 'This project is already starting in another terminal. Wait for that terminal to report the application address.'
        exit 0
    }
    if ($webState -notin @(0, 2)) { $probeMessages | Write-Host; exit 1 }
    & (Join-Path $PSScriptRoot 'setup-project.ps1') -NoLogin:$NoLogin -SkipFlutterRestore:($webState -eq 2)
    $runtime = Get-FypRuntime
    Set-FypRuntimeEnvironment $runtime
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ensure-account-service.ps1')
    if ($LASTEXITCODE -ne 0) { exit 1 }
    if ($webState -eq 2) {
        Write-Host 'The application is already running. Reusing it; a second server is not needed.'
        Write-Host 'Visitor: http://localhost:5173/'
        Write-Host 'Admin:   http://localhost:5173/#/admin'
        Write-Host 'Kiosk:   http://localhost:5173/#/kiosk'
        Write-Host 'Keep the original launcher terminal open while using the app.'
        exit 0
    }
    $state = @{pid=$PID;workspaceId=(Get-FypWorkspaceId);scriptPath=(Join-Path $PSScriptRoot 'run-project.ps1');createdAt=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')}
    [System.IO.File]::WriteAllText((Join-Path $script:FypProjectRoot '.local\web-launcher.json'), ($state | ConvertTo-Json))
    Write-Host 'Starting the application. Keep this terminal open.'
    Write-Host 'Open http://localhost:5173/ after Flutter reports that the app is being served.'
    $flutterArgs = @('--no-version-check','run','--release','-d','web-server','--web-hostname=127.0.0.1','--web-port=5173','--no-pub')
    if (Test-Path -LiteralPath (Join-Path $script:FypProjectRoot 'env.json')) { $flutterArgs += '--dart-define-from-file=env.json' }
    & $runtime.flutter @flutterArgs
    exit $LASTEXITCODE
} catch {
    Write-Host ('Startup stopped: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($ownsLaunch) { $launchMutex.ReleaseMutex() }
    if ($launchMutex) { $launchMutex.Dispose() }
}
