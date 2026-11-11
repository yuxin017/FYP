$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
Write-Host 'Configure the actual Situm building after its floorplan and positioning setup.'
$situmSecret = Read-Host 'Situm mobile SDK API key (hidden)' -AsSecureString
$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($situmSecret)
try {
    $mobileKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer).Trim()
    $buildingId = (Read-Host 'Situm building identifier').Trim()
    if (-not $mobileKey -or -not $buildingId) { throw 'The mobile SDK key and building identifier are required.' }
    $profileName = (Read-Host 'Situm profile (leave blank for default)').Trim()
    @{ SITUM_API_KEY = $mobileKey; SITUM_BUILDING_ID = $buildingId; SITUM_PROFILE = $profileName } | ConvertTo-Json | & $runtime.node (Join-Path $script:FypProjectRoot 'server\shared_config_cli.cjs') save-mobile
    if ($LASTEXITCODE -ne 0) { throw 'Situm settings could not be saved to Firebase.' }
    Write-Host 'Situm settings are shared through Firebase. Restart the application to load them.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    $mobileKey = $null
    $situmSecret.Dispose()
}
