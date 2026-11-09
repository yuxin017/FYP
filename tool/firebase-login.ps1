$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
& $runtime.node (Join-Path $env:FIREBASE_CLI_ROOT 'lib\bin\firebase.js') login --reauth
if ($LASTEXITCODE -ne 0) { throw 'Firebase sign-in was not completed.' }
& $runtime.node (Join-Path $PSScriptRoot 'firebase\check-access.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Sign in with an account that can access themeparksmartmanagement.' }
