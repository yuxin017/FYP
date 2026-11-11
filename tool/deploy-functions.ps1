$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
Write-Host 'Deploying the themepark Cloud Functions codebase to themeparksmartmanagement.'
Write-Host 'The Firebase project must already have Blaze billing enabled by its owner.'
& $runtime.node (Join-Path $env:FIREBASE_CLI_ROOT 'lib\bin\firebase.js') deploy --config firebase.themepark.json --only functions:themepark --project themeparksmartmanagement
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
@{ USE_FIREBASE_FUNCTIONS = $true } | ConvertTo-Json | & $runtime.node (Join-Path $script:FypProjectRoot 'server\shared_config_cli.cjs') save-mobile
if ($LASTEXITCODE -ne 0) { throw 'Functions deployed, but the shared routing setting could not be updated. Retry the configuration step.' }
Write-Host 'Cloud reservation routing enabled in shared Firebase settings. Restart the application to load it.'
