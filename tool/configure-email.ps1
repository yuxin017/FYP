$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime
Write-Host 'Configure Gmail for password OTPs and photo delivery.'
Write-Host 'Use a Google app password, not your usual Gmail password.'
Write-Host 'Google setup: https://myaccount.google.com/apppasswords'
$senderAddress = (Read-Host 'Sending Gmail address').Trim()
if ($senderAddress -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Enter a valid sending email address.' }
$appSecret = Read-Host '16-character Google app password (hidden)' -AsSecureString
$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecret)
try {
    $smtpSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer) -replace '\s', ''
    if ($smtpSecret -notmatch '^[a-zA-Z0-9]{16}$') { throw 'A Google app password must contain 16 characters.' }
    $settings = @{ smtp = @{ enabled = $true; host = 'smtp.gmail.com'; port = 465; security = 'ssl'; username = $senderAddress; password = $smtpSecret; from = $senderAddress } }
    $settings | ConvertTo-Json -Depth 10 | & $runtime.node (Join-Path $script:FypProjectRoot 'server\shared_config_cli.cjs') save-services
    if ($LASTEXITCODE -ne 0) { throw 'Email setup did not finish. The previous shared settings have been preserved.' }
    Write-Host 'The application API refreshes shared email settings automatically within one minute.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    $smtpSecret = $null
    $settings = $null
    $appSecret.Dispose()
}
