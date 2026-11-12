param([switch]$NoLogin, [switch]$SkipFlutterRestore, [switch]$SkipFirebaseAccess, [string]$ToolCache)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
Set-Location -LiteralPath $script:FypProjectRoot
if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'This setup supports Windows x64. Use the documented manual platform setup on other systems.' }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows, then reopen PowerShell and run this command again: https://git-scm.com/download/win' }
if (-not (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\tar.exe'))) { throw 'Windows 10/11 tar.exe is required to extract the pinned toolchains.' }
if (-not $ToolCache) { $ToolCache = if ($env:FYP_TOOL_CACHE) { $env:FYP_TOOL_CACHE } else { Join-Path $env:LOCALAPPDATA 'ThemeParkFYP\toolchains' } }
New-Item -ItemType Directory -Force -Path (Join-Path $script:FypProjectRoot '.local') | Out-Null
$manifest = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'toolchains.json')) | ConvertFrom-Json
$existing = $null
try { $existing = Get-FypRuntime } catch { }
$runtime = [ordered]@{}
foreach ($kind in @('node', 'flutter', 'python')) {
    $release = $manifest.$kind
    $candidate = if ($existing) { $existing.$kind } else { $null }
    if (-not (Test-FypTool $candidate $kind $release.version)) {
        $command = Get-Command $(if ($kind -eq 'flutter') { 'flutter.bat' } else { "$kind.exe" }) -ErrorAction SilentlyContinue
        $candidate = if ($command) { $command.Source } else { $null }
    }
    if (-not (Test-FypTool $candidate $kind $release.version)) { $candidate = Install-FypTool $kind $release $ToolCache }
    if ($kind -eq 'python' -and -not (Test-FypPythonInstaller $candidate)) {
        # Packaged Windows apps can redirect individual AppData executables and
        # leave a split Python installation. Keep pip's resource checks intact;
        # restore the checksum-pinned SDK in this writable project instead.
        Write-Host 'Preparing a consistent project-local Python installer...'
        $pythonCache = Join-Path $script:FypProjectRoot '.local\toolchains'
        New-Item -ItemType Directory -Path $pythonCache -Force | Out-Null
        $archiveName = 'python-' + $release.version + '.' + $release.format
        $cachedArchive = Join-Path $ToolCache $archiveName
        $localArchive = Join-Path $pythonCache $archiveName
        if ((Test-Path -LiteralPath $cachedArchive) -and -not (Test-Path -LiteralPath $localArchive) -and (Get-FypHash $cachedArchive) -eq $release.sha256) {
            Copy-Item -LiteralPath $cachedArchive -Destination $localArchive
        }
        $candidate = Install-FypTool $kind $release $pythonCache
        if (-not (Test-FypPythonInstaller $candidate)) { throw 'The pinned Python installer could not initialize. Retry setup from a normal PowerShell terminal in this project.' }
    }
    $runtime[$kind] = $candidate
    Write-Host "$kind $($release.version) ready."
}
$runtimeFile = Join-Path $script:FypProjectRoot '.local\runtime.json'
[System.IO.File]::WriteAllText($runtimeFile, ($runtime | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
$runtime = Get-FypRuntime
Set-FypRuntimeEnvironment $runtime

foreach ($folder in @('functions', 'tool\firebase')) {
    $directory = Join-Path $script:FypProjectRoot $folder
    $lock = Join-Path $directory 'package-lock.json'
    if (-not (Test-Path -LiteralPath $lock)) { throw "The repository is missing $folder\package-lock.json. Copy the complete project and retry." }
    $stamp = Join-Path $directory 'node_modules\.fyp-lock.sha256'
    $expected = Get-FypHash $lock
    if (-not (Test-Path -LiteralPath $stamp) -or [System.IO.File]::ReadAllText($stamp).Trim() -ne $expected) {
        Write-Host "Restoring locked $folder dependencies..."
        Invoke-FypNpm $runtime @('ci', '--prefix', $directory, '--no-audit', '--no-fund')
        [System.IO.File]::WriteAllText($stamp, $expected)
    }
}

$flutterState = Join-Path $script:FypProjectRoot '.local\flutter-ready.sha256'
$packages = Join-Path $script:FypProjectRoot '.dart_tool\package_config.json'
if (-not $SkipFlutterRestore) {
    Write-Host 'Restoring Flutter packages with the project SDK...'
    # An IDE may run pub get with another Flutter SDK before this launcher.
    # Allow pub to restore the packages required by the pinned project SDK.
    & $runtime.flutter --no-version-check pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency restore failed. Retry setup after resolving the error above.' }
    $flutterHash = (Get-FypHash (Join-Path $script:FypProjectRoot 'pubspec.lock')) + (Get-FypHash (Join-Path $script:FypProjectRoot 'pubspec.yaml'))
    if (-not (Test-Path -LiteralPath $flutterState) -or [System.IO.File]::ReadAllText($flutterState).Trim() -ne $flutterHash) {
        & $runtime.flutter --no-version-check precache --web
        if ($LASTEXITCODE -ne 0) { throw 'Flutter web tool download failed. Check your internet connection and retry.' }
    }
    [System.IO.File]::WriteAllText($flutterState, $flutterHash)
}

$aiState = Join-Path $script:FypProjectRoot '.local\ai-ready.sha256'
$aiHash = (Get-FypHash (Join-Path $script:FypProjectRoot 'ai\requirements.txt')) + (Get-FypHash (Join-Path $script:FypProjectRoot 'ai\model_manifest.json')) + $runtime.python
& {
    $probeInfo = New-Object System.Diagnostics.ProcessStartInfo
    $probeInfo.FileName = $runtime.python
    $probeInfo.Arguments = '"' + (Join-Path $script:FypProjectRoot 'ai\verify_environment.py') + '"'
    $probeInfo.UseShellExecute = $false
    $probeInfo.CreateNoWindow = $true
    $probeInfo.RedirectStandardOutput = $true
    $probeInfo.RedirectStandardError = $true
    $probe = [System.Diagnostics.Process]::Start($probeInfo)
    $probeOutput = $probe.StandardOutput.ReadToEndAsync()
    $probeError = $probe.StandardError.ReadToEndAsync()
    if (-not $probe.WaitForExit(60000)) { $probe.Kill(); throw 'AI dependency inspection timed out. Retry setup after closing the old application.' }
    $null = $probeOutput.GetAwaiter().GetResult()
    $null = $probeError.GetAwaiter().GetResult()
    $aiReady = $probe.ExitCode -eq 0
    $probe.Dispose()
    if (-not $aiReady) {
        # Release this folder's worker DLLs before replacing AI dependencies.
        if (Test-Path -LiteralPath (Join-Path $script:FypProjectRoot '.local\account-service.pid')) { & (Join-Path $PSScriptRoot 'stop-account-service.ps1') }
        & (Join-Path $PSScriptRoot 'setup-ai.ps1') -PythonPath $runtime.python
    }
    [System.IO.File]::WriteAllText($aiState, $aiHash)
}
& $runtime.python (Join-Path $script:FypProjectRoot 'ai\verify_environment.py')
if ($LASTEXITCODE -ne 0) { throw 'AI dependency verification failed. Run tool\setup.cmd again. If it persists, run tool\setup-ai.ps1 with your Python 3.12 path.' }

if (-not $SkipFirebaseAccess) {
$cli = Join-Path $env:FIREBASE_CLI_ROOT 'lib\bin\firebase.js'
& $runtime.node (Join-Path $PSScriptRoot 'firebase\check-access.cjs')
if ($LASTEXITCODE -eq 2 -and -not $NoLogin) {
    Write-Host 'Complete Firebase sign-in in your browser using an account with project access.'
    & $runtime.node $cli login
    if ($LASTEXITCODE -ne 0) { throw 'Firebase sign-in was not completed. Run tool\firebase-login.cmd, then retry.' }
    & $runtime.node (Join-Path $PSScriptRoot 'firebase\check-access.cjs')
}
if ($LASTEXITCODE -ne 0) { throw 'Firebase access is required on this PC. Run tool\firebase-login.cmd using an authorized account.' }
& $runtime.node (Join-Path $script:FypProjectRoot 'server\shared_config_cli.cjs') sync-mobile
if ($LASTEXITCODE -ne 0) { throw 'Shared application configuration could not be loaded. Check your Firebase project access and retry.' }
}
Write-Host 'Project setup is ready on this computer.'
