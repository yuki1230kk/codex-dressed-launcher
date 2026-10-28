# An observer only: never launches, closes or resizes the client.
function Show-StartupAnimation {
    param([string]$Video, [object]$Codex, [System.Diagnostics.Process]$Worker)
    if (-not $Video -or -not (Test-Path -LiteralPath $Video -PathType Leaf)) {
        Write-Warning 'Animation skipped: video missing.'; return
    }
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Initialize-NativeWindow
    $deadline = (Get-Date).AddSeconds(45)
    $stable = 0; $previous = ''; $client = $null; $bounds = $null
    while ((Get-Date) -lt $deadline) {
        foreach ($item in @(Get-DreamSkinCodexProcesses -Codex $Codex)) {
            $candidate = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
            if ($null -eq $candidate -or $candidate.MainWindowHandle -eq [IntPtr]::Zero) { continue }
            $r = New-Object Dressed.NativeWindow+Rect
            if (-not [Dressed.NativeWindow]::GetWindowRect($candidate.MainWindowHandle, [ref]$r)) { continue }
            if ([Dressed.NativeWindow]::IsIconic($candidate.MainWindowHandle)) { continue }
            if ($r.Right-$r.Left -lt 350 -or $r.Bottom-$r.Top -lt 250) { continue }
            $key = "$($candidate.Id):$($r.Left):$($r.Top):$($r.Right):$($r.Bottom)"
            if ($key -ceq $previous) { $stable++ } else { $stable=1; $previous=$key }
            if ($stable -ge 2) { $client=$candidate; $bounds=$r; break }
        }
        if ($null -ne $client) { break }
        $Worker.Refresh()
        if ($Worker.HasExited -and $Worker.ExitCode -ne 0) { return }
        Start-Sleep -Milliseconds 200
    }
    if ($null -eq $client) { Write-Warning 'Animation skipped: no stable client window.'; return }
    $window = New-Object System.Windows.Window
    $window.Title = 'Codex startup animation'; $window.WindowStyle = 'None'
    $window.ResizeMode = 'NoResize'; $window.ShowInTaskbar = $false; $window.Topmost = $true
    $window.Background = [System.Windows.Media.Brushes]::Black
    # Convert physical window coordinates to WPF DIPs, including display scaling.
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
    $null = $helper.EnsureHandle()
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($helper.Handle)
    $transform = $source.CompositionTarget.TransformFromDevice
    $origin = $transform.Transform([System.Windows.Point]::new($bounds.Left,$bounds.Top))
    $size = $transform.Transform([System.Windows.Vector]::new($bounds.Right-$bounds.Left,$bounds.Bottom-$bounds.Top))
    $window.Left=$origin.X; $window.Top=$origin.Y; $window.Width=$size.X; $window.Height=$size.Y
    $media = New-Object System.Windows.Controls.MediaElement
    $media.LoadedBehavior='Manual'; $media.UnloadedBehavior='Stop'; $media.Stretch='Uniform'
    $media.Source=[Uri]::new([IO.Path]::GetFullPath($Video)); $window.Content=$media
    $media.Add_MediaEnded({ $window.Close() })
    $media.Add_MediaFailed({ $window.Close() })
    $window.Add_KeyDown({ if ($_.Key -eq 'Escape') { $window.Close() } })
    $window.Add_Loaded({ $media.Play() })
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval=[TimeSpan]::FromMilliseconds(200)
    $animationDeadline=(Get-Date).AddSeconds(30)
    $timer.Add_Tick({
        $client.Refresh()
        if ($client.HasExited -or (Get-Date) -ge $animationDeadline) { $window.Close() }
    })
    try { $timer.Start(); $null=$window.ShowDialog() }
    finally { $timer.Stop(); $media.Stop(); Activate-Client @($client.Id) }
}
