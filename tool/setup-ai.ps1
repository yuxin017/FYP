param([string]$PythonPath)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $PythonPath) {
    . (Join-Path $PSScriptRoot 'project-runtime.ps1')
    try { $PythonPath = (Get-FypRuntime).python }
    catch { $PythonPath = (Get-Command python.exe -ErrorAction Stop).Source }
}
$PythonPath = (Resolve-Path -LiteralPath $PythonPath).Path
& $PythonPath -c 'import sys; assert sys.version_info[:2] == (3,12), "Use Python 3.12 for the shared AI environment."'
if ($LASTEXITCODE -ne 0) { throw 'Python 3.12 is required.' }
$dependencyPath = Join-Path $projectPath '.local\python-deps'
& $PythonPath -m pip install --target $dependencyPath --upgrade --only-binary=:all: -r (Join-Path $projectPath 'ai\requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'AI dependency installation failed.' }
& $PythonPath (Join-Path $projectPath 'ai\download_models.py')
if ($LASTEXITCODE -ne 0) { throw 'AI model verification failed.' }
& $PythonPath (Join-Path $projectPath 'ai\verify_environment.py')
if ($LASTEXITCODE -ne 0) { throw 'AI environment verification failed.' }
[System.IO.File]::WriteAllText((Join-Path $projectPath '.local\python.path'), $PythonPath)
Write-Output 'AI dependencies and models are ready.'
