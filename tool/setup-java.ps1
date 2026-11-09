$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$projectPath=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$javaRoot=Join-Path $projectPath '.local\java21'
$jdkHome=Join-Path $javaRoot 'jdk-21.0.13+9'
if(-not (Test-Path -LiteralPath (Join-Path $jdkHome 'bin\javac.exe'))){
    New-Item -ItemType Directory -Force -Path $javaRoot | Out-Null
    $archive=Join-Path $javaRoot 'jdk21.zip'
    Invoke-WebRequest 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13_9.zip' -OutFile $archive -UseBasicParsing
    $algorithm=[System.Security.Cryptography.SHA256]::Create()
    try{$checksum=[System.BitConverter]::ToString($algorithm.ComputeHash([System.IO.File]::ReadAllBytes($archive))).Replace('-','').ToLowerInvariant()}finally{$algorithm.Dispose()}
    if($checksum -ne 'a4dbaa05fca4bd89d84584e58c459bd732efebb1722af80ab13c6516832004f9'){throw 'Java SDK checksum did not match the verified release.'}
    Expand-Archive -LiteralPath $archive -DestinationPath $javaRoot -Force
}
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
$flutter=(Get-FypRuntime).flutter
& $flutter config --jdk-dir $jdkHome
if($LASTEXITCODE -ne 0){throw 'Unable to configure the Java SDK for Flutter.'}
& (Join-Path $jdkHome 'bin\java.exe') --version
Write-Output 'Flutter Android builds now use the verified Temurin Java 21 SDK.'
