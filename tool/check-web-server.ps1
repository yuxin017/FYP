param([ValidateRange(1024, 65535)][int]$Port = 5173)

# Exit 0: port is free. Exit 2: this app is already served. Exit 1: busy/unverified.
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$listeners = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
if (-not ($listeners | Where-Object { $_.Port -eq $Port })) { exit 0 }

$client = $null
$handler = $null
$algorithm = $null
try {
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.UseProxy = $false
    $handler.AllowAutoRedirect = $false
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(5)
    $baseAddress = "http://127.0.0.1:$Port"
    $index = $client.GetStringAsync("$baseAddress/").GetAwaiter().GetResult()
    $sourceIndex = [System.IO.File]::ReadAllText((Join-Path $projectPath 'web\index.html'))
    $title = [regex]::Match($sourceIndex, '<title>([^<]+)</title>').Groups[1].Value
    if (-not $title -or -not $index.Contains("<title>$title</title>") -or -not $index.Contains('flutter_bootstrap.js')) {
        throw 'The existing page does not match this application.'
    }

    # Compare the actual application bundle, so another website is never reused
    # merely because it happens to occupy the usual port or has the same title.
    $bundlePath = Join-Path $projectPath 'build\web\main.dart.js'
    if (-not (Test-Path -LiteralPath $bundlePath -PathType Leaf)) { throw 'No local bundle is available to verify.' }
    $servedBundle = $client.GetByteArrayAsync("$baseAddress/main.dart.js").GetAwaiter().GetResult()
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    $servedHash = [System.BitConverter]::ToString($algorithm.ComputeHash($servedBundle))
    $bundleStream = [System.IO.File]::OpenRead($bundlePath)
    try { $localHash = [System.BitConverter]::ToString($algorithm.ComputeHash($bundleStream)) }
    finally { $bundleStream.Dispose() }
    if ($servedHash -ne $localHash) { throw 'The running bundle differs from this project build.' }
    exit 2
} catch {
    Write-Output "Port $Port is already in use, but this project's running app could not be verified."
    Write-Output 'If another launcher is still compiling, wait for it to finish and run this command again.'
    Write-Output 'Otherwise close the old launcher with Ctrl+C, then retry. No other application was stopped.'
    exit 1
} finally {
    if ($algorithm) { $algorithm.Dispose() }
    if ($client) { $client.Dispose() }
    if ($handler) { $handler.Dispose() }
}
