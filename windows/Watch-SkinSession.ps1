param([string]$Engine, [string]$ThemeDirectory, [int]$Port, [string]$SessionFile)
$ErrorActionPreference='Stop'
$daemon=$null
try {
    . (Join-Path $Engine 'scripts\common-windows.ps1')
    $codex=Get-DreamSkinCodexInstall
    $clients=@(Get-DreamSkinCodexProcesses -Codex $codex | ForEach-Object {
        Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
    })
    if ($clients.Count -eq 0) { throw 'Client closed before injection.' }
    $node=Get-DreamSkinNodeRuntime
    $injector=Join-Path $Engine 'scripts\injector.mjs'
    $root=Split-Path -Parent $SessionFile
    $arguments=@($injector,'--watch','--port',"$Port",'--theme-dir',$ThemeDirectory)
    $daemon=Start-Process -FilePath $node.Path -ArgumentList (ConvertTo-DreamSkinArgumentLine -Arguments $arguments) `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'injector.log') `
        -RedirectStandardError (Join-Path $root 'injector-error.log')
    $deadline=(Get-Date).AddSeconds(35)
    while ($true) {
        $daemon.Refresh()
        if ($daemon.HasExited) { break }
        $living=@($clients | Where-Object { $_.Refresh(); -not $_.HasExited })
        if ($living.Count -eq 0) { break }
        $status=[IO.File]::ReadAllText($SessionFile)
        if ($status -eq 'failed' -or ($status -ne 'active' -and (Get-Date) -ge $deadline)) { break }
        Start-Sleep -Milliseconds 300
    }
} finally {
    if ($null -ne $daemon) {
        $daemon.Refresh()
        if (-not $daemon.HasExited) { $daemon.Kill(); $daemon.WaitForExit() }
        $daemon.Dispose()
    }
    Remove-Item -LiteralPath $SessionFile -ErrorAction SilentlyContinue
}
