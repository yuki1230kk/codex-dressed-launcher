[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath, [Parameter(Mandatory=$true)][string]$ThemeId)
$ErrorActionPreference = 'Stop'
$sessionFile=$null
. (Join-Path $PSScriptRoot 'Core.ps1')
try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $engine = [Environment]::ExpandEnvironmentVariables($config.engineRoot)
    . (Join-Path $engine 'scripts\common-windows.ps1')
    . (Join-Path $engine 'scripts\theme-windows.ps1')
    $codex = Get-DreamSkinCodexInstall
    if (@(Get-DreamSkinCodexProcesses -Codex $codex).Count -gt 0) { exit 21 }
    $themes = @(Get-DreamSkinSavedThemes)
    $selected = @($themes | Where-Object { $_.Id -ceq $ThemeId })
    if ($selected.Count -ne 1) { throw 'Theme ID is missing or ambiguous in the installed theme library.' }
    # Read/validate the installed pack. Never extract arbitrary ZIPs ourselves.
    $null = Read-DreamSkinTheme -ThemeDirectory $selected[0].Path
    $node = Get-DreamSkinNodeRuntime
    $port = Select-DreamSkinPort -PreferredPort 9341
    $root = Join-Path $env:LOCALAPPDATA 'CodexDressedLauncher'
    $profile = Join-Path $root 'cdp-profile'
    New-Item -ItemType Directory -Force -Path $profile | Out-Null
    Assert-DreamSkinCodexDirectLaunchTarget -Codex $codex
    if (@(Get-DreamSkinCodexProcesses -Codex $codex).Count -gt 0) { exit 21 }
    # Exactly ONE verified Store executable launch. No package-activation retry,
    # no Stop-DreamSkinCodex, and no restart/recovery launch on failure.
    $null = Start-DreamSkinCodexDirect -Codex $codex -Arguments @(
        '--remote-debugging-address=127.0.0.1', "--remote-debugging-port=$port", "--user-data-dir=$profile"
    )
    $deadline = (Get-Date).AddSeconds(45)
    while ($null -eq (Get-DreamSkinVerifiedCdpIdentity -Port $port -Codex $codex)) {
        if ((Get-Date) -ge $deadline) { throw 'No verified skin endpoint after 45 seconds; client left running, no restart.' }
        Start-Sleep -Milliseconds 300
    }
    $injector = Join-Path $engine 'scripts\injector.mjs'
    $sessionFile=Join-Path $root ('.session-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($sessionFile,'pending')
    $watch=Join-Path $PSScriptRoot 'Watch-SkinSession.ps1'
    $command='& ' + (ConvertTo-PSLiteral $watch) + ' -Engine ' + (ConvertTo-PSLiteral $engine) + ' -ThemeDirectory ' + (ConvertTo-PSLiteral $selected[0].Path) + ' -Port ' + $port + ' -SessionFile ' + (ConvertTo-PSLiteral $sessionFile)
    $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $supervisor=Start-Process -FilePath $powershell -ArgumentList @('-NoProfile','-NonInteractive','-EncodedCommand',(ConvertTo-EncodedCommand $command)) -WindowStyle Hidden -PassThru
    & $node.Path $injector --verify --port $port --theme-dir $selected[0].Path --timeout-ms 20000
    $verifyExit=$LASTEXITCODE
    $supervisor.Refresh()
    if ($verifyExit -ne 0 -or $supervisor.HasExited -or -not (Test-Path -LiteralPath $sessionFile)) {
        throw 'Skin renderer verification failed; client left running, no restart.'
    }
    [IO.File]::WriteAllText($sessionFile,'active')
    Write-Output "Verified skin: $ThemeId"
    exit 0
} catch {
    if ($sessionFile -and (Test-Path -LiteralPath $sessionFile)) { [IO.File]::WriteAllText($sessionFile,'failed') }
    Write-Error $_ -ErrorAction Continue
    exit 1
}
