$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project-runtime.ps1')
$marker = Join-Path $script:FypProjectRoot '.local\web-launcher.json'
if (Test-Path -LiteralPath $marker) {
    $state = [System.IO.File]::ReadAllText($marker) | ConvertFrom-Json
    $launcher = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.pid)"
    if ($launcher) {
        $scriptPath = Join-Path $script:FypProjectRoot 'tool\run-project.ps1'
        $started = ([DateTime]$launcher.CreationDate).ToUniversalTime()
        $recorded = if ($state.createdAt -is [DateTime]) { $state.createdAt.ToUniversalTime() } else { [DateTime]::Parse($state.createdAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() }
        $runsLauncher = $launcher.Name -in @('powershell.exe','pwsh.exe') -and $launcher.CommandLine -match '(?i)-File\s+("[^"]*[\\/]tool[\\/]run-project\.ps1"|[^\s]*[\\/]tool[\\/]run-project\.ps1)(?:\s|$)'
        $sameScript = -not $state.scriptPath -or $state.scriptPath -eq $scriptPath
        if ($state.workspaceId -ne (Get-FypWorkspaceId) -or -not $sameScript -or [Math]::Abs(($started - $recorded).TotalSeconds) -gt 2 -or -not $runsLauncher -or $launcher.ProcessId -eq $PID) { throw 'The saved web launcher could not be verified. No web process was stopped.' }
        $all = @(Get-CimInstance Win32_Process)
        $owned = New-Object System.Collections.Generic.List[object]
        $parents = @([int]$launcher.ProcessId)
        while ($parents.Count -gt 0) {
            $children = @($all | Where-Object { $parents -contains [int]$_.ParentProcessId })
            foreach ($child in $children) { $owned.Add($child) }
            $parents = @($children | ForEach-Object { [int]$_.ProcessId })
        }
        foreach ($process in $owned) {
            $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ProcessId)"
            if ($current -and $current.CreationDate -eq $process.CreationDate) { Stop-Process -Id $process.ProcessId -ErrorAction SilentlyContinue }
        }
        Stop-Process -Id $launcher.ProcessId -ErrorAction SilentlyContinue
        Write-Host 'Application web server stopped.'
    }
}
& (Join-Path $PSScriptRoot 'stop-account-service.ps1')
