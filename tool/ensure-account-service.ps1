$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
$projectPath = $script:FypProjectRoot
$workspaceId = Get-FypWorkspaceId
$sourcePaths = @(Get-ChildItem -LiteralPath (Join-Path $projectPath 'server') -Filter '*.cjs' -File) + @(Get-ChildItem -LiteralPath (Join-Path $projectPath 'functions\src') -Filter '*.js' -File)
$sourcePaths += @(Get-ChildItem -LiteralPath (Join-Path $projectPath 'ai') -Filter '*.py' -File)
$sourcePaths += Get-Item -LiteralPath (Join-Path $projectPath '.local\runtime.json'), (Join-Path $projectPath 'functions\package-lock.json'), (Join-Path $projectPath 'tool\firebase\package-lock.json')
$sourceHash = (($sourcePaths | Sort-Object FullName | ForEach-Object { Get-FypHash $_.FullName }) -join '')
$hashPath = Join-Path $projectPath '.local\account-service.hash'
$health = $null
try { $health = Invoke-RestMethod 'http://127.0.0.1:8787/health' -TimeoutSec 2 } catch { }
if ($health) {
    if (-not $health.ok -or $health.projectId -ne 'themeparksmartmanagement') { throw 'Port 8787 belongs to another service. Close it before starting this application.' }
    if ($health.workspaceId -and $health.workspaceId -ne $workspaceId) { throw 'Another project folder is running its API on port 8787. Run tool\stop-app.cmd in that folder first.' }
    if ($health.workspaceId -eq $workspaceId -and (Test-Path -LiteralPath $hashPath) -and [System.IO.File]::ReadAllText($hashPath).Trim() -eq $sourceHash) { Write-Output 'Account services ready.'; exit 0 }
    & (Join-Path $PSScriptRoot 'stop-account-service.ps1')
}
$scratchPath = Join-Path $projectPath '.local'
$entryPoint = Join-Path $projectPath 'server\start-accounts.cjs'
$service = Start-Process -FilePath $runtime.node -ArgumentList ('"' + $entryPoint + '"') -WorkingDirectory $projectPath -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $scratchPath 'accounts.stdout.log') -RedirectStandardError (Join-Path $scratchPath 'accounts.stderr.log')
[System.IO.File]::WriteAllText((Join-Path $scratchPath 'account-service.pid'), [string]$service.Id)
[System.IO.File]::WriteAllText($hashPath, $sourceHash)
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 250
    $service.Refresh()
    if ($service.HasExited) { throw 'Account service stopped. See .local\accounts.stderr.log; run tool\setup.cmd to check Firebase sign-in and dependencies.' }
    try { $health = Invoke-RestMethod 'http://127.0.0.1:8787/health' -TimeoutSec 1 } catch { continue }
    if ($health.ok -and $health.projectId -eq 'themeparksmartmanagement' -and $health.workspaceId -eq $workspaceId) { Write-Output 'Account services ready.'; exit 0 }
}
throw 'Account services did not become ready. See .local\accounts.stderr.log.'
