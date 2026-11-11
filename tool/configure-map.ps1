$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
$mobile = @{}
Write-Host 'Mapbox account tokens: https://console.mapbox.com/account/access-tokens/'
$mapToken = (Read-Host 'Default public Mapbox token (starts with pk.)').Trim()
if ($mapToken -notmatch '^pk\.[A-Za-z0-9_.-]+$') { throw 'Use a public pk. token from your Mapbox account.' }
$mobile.MAPBOX_PUBLIC_TOKEN = $mapToken
$venue = Get-Content -LiteralPath (Join-Path $script:FypProjectRoot 'config\venue.json') -Raw | ConvertFrom-Json
foreach ($key in @('north','south','east','west')) { $mobile[('PARK_' + $key.ToUpperInvariant())] = $venue.$key.ToString([Globalization.CultureInfo]::InvariantCulture) }
$mobile | ConvertTo-Json -Depth 10 | & $runtime.node (Join-Path $script:FypProjectRoot 'server\shared_config_cli.cjs') save-mobile
if ($LASTEXITCODE -ne 0) { throw 'Mapbox configuration could not be saved to Firebase.' }
Write-Host 'Mapbox settings are shared through Firebase. Restart the app to load them.'
