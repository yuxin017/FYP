$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
& $runtime.node (Join-Path $script:FypProjectRoot 'server\shared_config_cli.cjs') check-email
exit $LASTEXITCODE
