$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'CodexDressedLauncher'
$app=Join-Path $root 'app'
if (-not (Test-Path -LiteralPath $app)) { return }
$item=Get-Item -LiteralPath $app
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing a redirected install directory.' }
if ([IO.File]::ReadAllText((Join-Path $app '.launcher-id')) -cne 'community.codex-dressed-launcher') { throw 'Unrelated directory; refusing removal.' }
$shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex 皮肤与动画.lnk'
if (Test-Path -LiteralPath $shortcut) {
    $shell=New-Object -ComObject WScript.Shell
    $link=$shell.CreateShortcut($shortcut)
    . (Join-Path $PSScriptRoot 'Core.ps1')
    $expected='-NoProfile -STA -WindowStyle Hidden -EncodedCommand ' + (ConvertTo-EncodedCommand ('& ' + (ConvertTo-PSLiteral (Join-Path $app 'Launch.ps1'))))
    if ($link.Arguments -ceq $expected) { Remove-Item -LiteralPath $shortcut }
}
Remove-Item -LiteralPath $app -Recurse -Force
Write-Output 'Entry removed. Client, Dream Skin, themes, media, logs and config/profile are preserved. Quit the client to end this skin session.'
