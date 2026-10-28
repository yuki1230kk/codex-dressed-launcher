param([Parameter(Mandatory=$true)][string]$ConfigPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
$config=Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$null=Select-ThemeId -Ids @($config.themeIDs) -Previous ''
$engine=[Environment]::ExpandEnvironmentVariables($config.engineRoot)
foreach ($file in @('common-windows.ps1','theme-windows.ps1','injector.mjs')) {
    if (-not (Test-Path -LiteralPath (Join-Path $engine "scripts\$file") -PathType Leaf)) { throw "Missing Dream Skin dependency: $file. Correct engineRoot." }
}
$root=Join-Path $env:LOCALAPPDATA 'CodexDressedLauncher'
$app=Join-Path $root 'app'
if (Test-Path -LiteralPath $app) { throw 'Launcher already installed. Uninstall it first; configuration is preserved.' }
$shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex 皮肤与动画.lnk'
if (Test-Path -LiteralPath $shortcut) { throw 'Shortcut already exists; refusing replacement.' }
New-Item -ItemType Directory -Force -Path $root | Out-Null
$stage=Join-Path $root ('.install-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $stage | Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' | Copy-Item -Destination $stage
    [IO.File]::WriteAllText((Join-Path $stage '.launcher-id'),'community.codex-dressed-launcher')
    $targetConfig=Join-Path $root 'config.json'
    if (-not (Test-Path -LiteralPath $targetConfig)) { Copy-Item -LiteralPath $ConfigPath -Destination $targetConfig }
    Move-Item -LiteralPath $stage -Destination $app
    $shell=New-Object -ComObject WScript.Shell
    $link=$shell.CreateShortcut($shortcut)
    $link.TargetPath=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $command='& ' + (ConvertTo-PSLiteral (Join-Path $app 'Launch.ps1'))
    $link.Arguments='-NoProfile -STA -WindowStyle Hidden -EncodedCommand ' + (ConvertTo-EncodedCommand $command)
    $link.WorkingDirectory=$app
    $link.Description='Random skin and one client launch with a window-sized animation'
    $link.Save()
    Write-Output "Installed: $shortcut"
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
