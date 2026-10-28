function Select-ThemeId {
    param([string[]]$Ids, [string]$Previous)
    $unique = @($Ids | Sort-Object -Unique)
    if ($unique.Count -eq 0) { throw 'Configure at least one installed theme ID.' }
    foreach ($id in $unique) {
        if ($id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') { throw "Invalid theme ID: $id" }
    }
    $others = @($unique | Where-Object { $_ -cne $Previous })
    if ($others.Count -gt 0) { return ($others | Get-Random) }
    return ($unique | Get-Random)
}
function ConvertTo-PSLiteral([string]$Value) { return "'" + $Value.Replace("'", "''") + "'" }
function ConvertTo-EncodedCommand([string]$Command) {
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}
function Initialize-NativeWindow {
    if ('Dressed.NativeWindow' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Dressed {
 public static class NativeWindow {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 }
}
'@
}
function Activate-Client([int[]]$ProcessIds) {
    Initialize-NativeWindow
    foreach ($processId in $ProcessIds) {
        $p = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($null -ne $p -and $p.MainWindowHandle -ne [IntPtr]::Zero) {
            if ([Dressed.NativeWindow]::IsIconic($p.MainWindowHandle)) { [void][Dressed.NativeWindow]::ShowWindow($p.MainWindowHandle, 9) }
            [void][Dressed.NativeWindow]::SetForegroundWindow($p.MainWindowHandle)
            return
        }
    }
}
