$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
& (Join-Path $PSScriptRoot 'setup-project.ps1') -SkipFirebaseAccess
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
& (Join-Path $PSScriptRoot 'setup-java.ps1')
$env:JAVA_HOME = Join-Path $script:FypProjectRoot '.local\java21\jdk-21.0.13+9'
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH
& $runtime.node (Join-Path $env:FIREBASE_CLI_ROOT 'lib\bin\firebase.js') emulators:start --config firebase.rules-checks.json --project demo-themepark-fyp --only auth,firestore
exit $LASTEXITCODE
