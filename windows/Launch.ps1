[CmdletBinding()]
param([string]$ConfigPath = (Join-Path $env:LOCALAPPDATA 'CodexDressedLauncher\config.json'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
$mutex = New-Object Threading.Mutex($false, 'Local\CodexDressedLauncher')
$held = $false
try {
    try { $held=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held=$true }
    if (-not $held) { exit 0 }
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $engine = [Environment]::ExpandEnvironmentVariables($config.engineRoot)
    . (Join-Path $engine 'scripts\common-windows.ps1')
    $codex = Get-DreamSkinCodexInstall
    $existing = @(Get-DreamSkinCodexProcesses -Codex $codex)
    if ($existing.Count -gt 0) { Activate-Client @($existing | ForEach-Object { $_.ProcessId }); exit 0 }
    $root = Join-Path $env:LOCALAPPDATA 'CodexDressedLauncher'
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $lastPath = Join-Path $root 'last-theme.txt'
    $last = if (Test-Path -LiteralPath $lastPath) { [IO.File]::ReadAllText($lastPath) } else { '' }
    $selected = Select-ThemeId -Ids @($config.themeIDs) -Previous $last
    $workerPath = Join-Path $PSScriptRoot 'Start-SkinOnce.ps1'
    $command = '& ' + (ConvertTo-PSLiteral $workerPath) + ' -ConfigPath ' + (ConvertTo-PSLiteral $ConfigPath) + ' -ThemeId ' + (ConvertTo-PSLiteral $selected)
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $worker = Start-Process -FilePath $powershell -ArgumentList @('-NoProfile','-NonInteractive','-EncodedCommand',(ConvertTo-EncodedCommand $command)) `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'latest-launch.log') `
        -RedirectStandardError (Join-Path $root 'latest-error.log')
    try {
        . (Join-Path $PSScriptRoot 'Show-Animation.ps1')
        Show-StartupAnimation -Video ([Environment]::ExpandEnvironmentVariables($config.video)) -Codex $codex -Worker $worker
    } catch { Write-Warning "Animation skipped: $_" }
    # Keep the launch mutex while skin verification is still in progress.
    $worker.WaitForExit(); $worker.Refresh()
    if ($worker.ExitCode -eq 0) { [IO.File]::WriteAllText($lastPath,$selected) }
    elseif ($worker.ExitCode -ne 21) { throw "Skin not verified. See $root\latest-error.log. No client restart was attempted." }
} catch {
    Add-Type -AssemblyName PresentationFramework
    [void][System.Windows.MessageBox]::Show($_.Exception.Message, 'Codex skin launcher')
    exit 1
} finally {
    if ($held) { $mutex.ReleaseMutex() }; $mutex.Dispose()
}
