$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Get-ChildItem -LiteralPath (Join-Path $root 'windows') -Filter '*.ps1' | ForEach-Object {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count -gt 0) { throw ($errors | Out-String) }
}
. (Join-Path $root 'windows\Core.ps1')
for ($n=0; $n -lt 100; $n++) {
    if ((Select-ThemeId @('a','b','b') 'a') -cne 'b') { throw 'Immediate repeat.' }
}
if ((Select-ThemeId @('a','a') 'a') -cne 'a') { throw 'Single theme failed.' }
foreach ($bad in @('../bad','a;exit','')) {
    $rejected=$false
    try { $null=Select-ThemeId @($bad) '' } catch { $rejected=$true }
    if (-not $rejected) { throw 'Invalid ID accepted.' }
}
$literal=ConvertTo-PSLiteral "C:\A user's files\test.ps1"
if ($literal -cne "'C:\A user''s files\test.ps1'") { throw 'Path quoting failed.' }
$worker=Get-Content -LiteralPath (Join-Path $root 'windows\Start-SkinOnce.ps1') -Raw
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($worker,[ref]$tokens,[ref]$errors)
$commands=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
if (@($commands | Where-Object { $_ -eq 'Start-DreamSkinCodexDirect' }).Count -ne 1) { throw 'Expected exactly one direct-launch call site.' }
foreach ($forbidden in @('Start-DreamSkinCodex','Start-DreamSkinCodexForDebugging','Stop-DreamSkinCodex')) {
    if ($commands -contains $forbidden) { throw "Forbidden restart/fallback operation: $forbidden" }
}
Write-Output 'PASS: PowerShell syntax, selection, argument quoting and single-launch call contract. GUI not tested.'

# Run the actual worker in a child shell with fake dependency functions.
# No Windows client or real dependency files are touched.
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('dressed-tests-'+[guid]::NewGuid().ToString('N'))
$oldLocal=$env:LOCALAPPDATA; $oldSystem=$env:SystemRoot
$oldFixture=$env:DRESSED_FIXTURE; $oldCase=$env:DRESSED_CASE
try {
    $scripts=Join-Path $fixture 'engine/scripts'
    New-Item -ItemType Directory -Force -Path $scripts | Out-Null
    $env:LOCALAPPDATA=$fixture; $env:SystemRoot=$fixture; $env:DRESSED_FIXTURE=$fixture
    @'
function Record([string]$s) { Add-Content -LiteralPath (Join-Path $env:DRESSED_FIXTURE 'calls.txt') -Value $s }
function Get-DreamSkinCodexInstall { return [pscustomobject]@{Executable='fake-client'} }
function Get-DreamSkinCodexProcesses { param($Codex) if ($env:DRESSED_CASE -eq 'running') { return @([pscustomobject]@{ProcessId=123}) }; return @() }
function Get-DreamSkinNodeRuntime { return [pscustomobject]@{Path=(Join-Path $env:DRESSED_FIXTURE 'fake-node.ps1')} }
function Select-DreamSkinPort { param($PreferredPort) return 9341 }
function Assert-DreamSkinCodexDirectLaunchTarget { param($Codex) }
function Start-DreamSkinCodexDirect { param($Codex,$Arguments) Record 'launch'; if ($env:DRESSED_CASE -eq 'launch-failure') { throw 'Launch failed' }; return 123 }
function Get-DreamSkinVerifiedCdpIdentity { param($Port,$Codex) return [pscustomobject]@{Pid=123} }
function Start-Process {
    param($FilePath,$ArgumentList,$WindowStyle,[switch]$PassThru)
    Record 'supervisor'
    $p=[pscustomobject]@{HasExited=$false}
    $p | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
    return $p
}
'@ | Set-Content -LiteralPath (Join-Path $scripts 'common-windows.ps1') -Encoding UTF8
    @'
function Get-DreamSkinSavedThemes {
    if ($env:DRESSED_CASE -eq 'missing-theme') { return @() }
    return @([pscustomobject]@{Id='test-theme';Path=(Join-Path $env:DRESSED_FIXTURE 'theme')})
}
function Read-DreamSkinTheme { param($ThemeDirectory) }
'@ | Set-Content -LiteralPath (Join-Path $scripts 'theme-windows.ps1') -Encoding UTF8
    @'
Add-Content -LiteralPath (Join-Path $env:DRESSED_FIXTURE 'calls.txt') -Value 'verify'
$global:LASTEXITCODE=if ($env:DRESSED_CASE -eq 'verify-failure') { 1 } else { 0 }
'@ | Set-Content -LiteralPath (Join-Path $fixture 'fake-node.ps1') -Encoding UTF8
    $config=Join-Path $fixture 'config.json'
    @{engineRoot=(Join-Path $fixture 'engine');video='';themeIDs=@('test-theme')} | ConvertTo-Json | Set-Content -LiteralPath $config -Encoding UTF8
    $shell=(Get-Process -Id $PID).Path
    foreach ($case in @('success','running','missing-theme','launch-failure','verify-failure')) {
        $env:DRESSED_CASE=$case
        $callsPath=Join-Path $fixture 'calls.txt'
        [IO.File]::WriteAllText($callsPath,'')
        $ErrorActionPreference='Continue' # Windows PowerShell wraps native stderr as error records.
        & $shell -NoProfile -File (Join-Path $root 'windows/Start-SkinOnce.ps1') -ConfigPath $config -ThemeId test-theme 2>&1 | Out-Null
        $actual=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        $expected=if ($case -eq 'success') { 0 } elseif ($case -eq 'running') { 21 } else { 1 }
        if ($actual -ne $expected) { throw "Worker case $case returned $actual instead of $expected" }
        $calls=@(Get-Content -LiteralPath $callsPath)
        $launches=@($calls | Where-Object { $_ -eq 'launch' }).Count
        $expectedLaunches=if ($case -in @('running','missing-theme')) { 0 } else { 1 }
        if ($launches -ne $expectedLaunches) { throw "Worker case $case made $launches launch calls." }
        if ($case -eq 'success' -and ($calls -join ',') -cne 'launch,supervisor,verify') { throw 'Unexpected successful worker order.' }
    }
    Write-Output 'PASS: actual Windows worker with mocked dependencies: success, already running, missing theme, launch failure, render failure; never retries.'
} finally {
    $env:LOCALAPPDATA=$oldLocal; $env:SystemRoot=$oldSystem
    $env:DRESSED_FIXTURE=$oldFixture; $env:DRESSED_CASE=$oldCase
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
