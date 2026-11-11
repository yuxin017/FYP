$script:FypProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Get-FypHash([string]$File) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($File)
    try { return [System.BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}

function Get-FypWorkspaceId {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try { return [System.BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:FypProjectRoot.ToLowerInvariant()))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}

function Get-FypRuntime {
    $file = Join-Path $script:FypProjectRoot '.local\runtime.json'
    if (-not (Test-Path -LiteralPath $file)) { throw 'Run tool\setup.cmd to prepare this computer first.' }
    return ([System.IO.File]::ReadAllText($file) | ConvertFrom-Json)
}

function Set-FypRuntimeEnvironment($Runtime) {
    foreach ($key in @('node', 'flutter', 'python')) {
        if (-not (Test-Path -LiteralPath $Runtime.$key -PathType Leaf)) { throw "The $key runtime is missing. Run tool\setup.cmd again." }
    }
    $env:PATH = ([System.IO.Path]::GetDirectoryName($Runtime.node)) + ';' + ([System.IO.Path]::GetDirectoryName($Runtime.flutter)) + ';' + ([System.IO.Path]::GetDirectoryName($Runtime.python)) + ';' + (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0') + ';' + (Join-Path $env:SystemRoot 'System32') + ';' + $env:PATH
    $env:FYP_PYTHON = $Runtime.python
    $env:FIREBASE_CLI_ROOT = Join-Path $script:FypProjectRoot 'tool\firebase\node_modules\firebase-tools'
}

function Invoke-FypNpm($Runtime, [string[]]$Arguments) {
    $cli = Join-Path ([System.IO.Path]::GetDirectoryName($Runtime.node)) 'node_modules\npm\bin\npm-cli.js'
    & $Runtime.node $cli @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed. Resolve the error above and retry the same command.' }
}

function Test-FypTool([string]$Executable, [string]$Kind, [string]$Version) {
    if (-not $Executable -or -not (Test-Path -LiteralPath $Executable -PathType Leaf) -or $Executable -like '*\WindowsApps\*') { return $false }
    try {
        if ($Kind -eq 'flutter') {
            $metadata = Join-Path (Split-Path (Split-Path $Executable -Parent) -Parent) 'bin\cache\flutter.version.json'
            if (-not (Test-Path -LiteralPath $metadata)) { return $false }
            $installed = [System.IO.File]::ReadAllText($metadata) | ConvertFrom-Json
            return $installed.frameworkVersion -eq $Version -and $installed.dartSdkVersion -eq '3.11.0'
        }
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Executable
        $processInfo.Arguments = '--version'
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($processInfo)
        $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $valid = $process.ExitCode -eq 0 -and $output.Trim() -match ('^(v|Python )?' + [regex]::Escape($Version) + '$')
        $process.Dispose()
        return $valid
    } catch { return $false }
}

function Test-FypPythonInstaller([string]$Executable) {
    if (-not $Executable -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) { return $false }
    $probe = $null
    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $Executable
        $info.Arguments = '-c "import pip._internal.operations.install.wheel"'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $probe = [System.Diagnostics.Process]::Start($info)
        $output = $probe.StandardOutput.ReadToEndAsync()
        $errors = $probe.StandardError.ReadToEndAsync()
        if (-not $probe.WaitForExit(30000)) { $probe.Kill(); return $false }
        $null = $output.GetAwaiter().GetResult()
        $null = $errors.GetAwaiter().GetResult()
        return $probe.ExitCode -eq 0
    } catch { return $false }
    finally { if ($probe) { $probe.Dispose() } }
}

function Install-FypTool([string]$Kind, $Release, [string]$CacheRoot) {
    $destination = Join-Path $CacheRoot ($Kind + '-' + $Release.version)
    $executable = Join-Path $destination $Release.executable
    if (Test-FypTool $executable $Kind $Release.version) { return $executable }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $archive = Join-Path $CacheRoot ($Kind + '-' + $Release.version + '.' + $Release.format)
    if (-not (Test-Path -LiteralPath $archive) -or (Get-FypHash $archive) -ne $Release.sha256) {
        Write-Host "Downloading $Kind $($Release.version). First-time Flutter setup is a large download."
        $partial = $archive + '.partial'
        $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
        if (Test-Path -LiteralPath $curl) {
            & $curl --fail --location --retry 3 --output $partial $Release.url
            if ($LASTEXITCODE -ne 0) { throw "Unable to download $Kind. Check your internet connection and retry." }
        } else { Invoke-WebRequest -Uri $Release.url -OutFile $partial -UseBasicParsing }
        if ((Get-FypHash $partial) -ne $Release.sha256) { throw "$Kind download checksum did not match. Retry setup to download it again." }
        Move-Item -LiteralPath $partial -Destination $archive -Force
    }
    Write-Host "Extracting $Kind $($Release.version)..."
    & (Join-Path $env:SystemRoot 'System32\tar.exe') -xf $archive -C $destination
    if ($LASTEXITCODE -ne 0 -or -not (Test-FypTool $executable $Kind $Release.version)) { throw "$Kind extraction or version verification failed. Retry setup." }
    return $executable
}
