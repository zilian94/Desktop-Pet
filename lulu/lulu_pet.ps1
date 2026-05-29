Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class LuluNativeCursor {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);
}
"@

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AssetDir = Join-Path $AppDir "assets\states"

if (-not (Test-Path -LiteralPath $AssetDir)) {
    [System.Windows.MessageBox]::Show("Missing assets folder:`n$AssetDir", "lulu") | Out-Null
    exit 1
}

$StateAliases = @{
    idle = "idle"
    wave = "waving"
    jump = "jumping"
    work = "running"
    review = "review"
    failed = "failed"
    waiting = "waiting"
    run_right = "running-right"
    run_left = "running-left"
}

$Frames = @{}
Get-ChildItem -LiteralPath $AssetDir -Directory | ForEach-Object {
    $state = $_.Name
    $images = New-Object System.Collections.ArrayList
    Get-ChildItem -LiteralPath $_.FullName -Filter "*.png" | Sort-Object Name | ForEach-Object {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = [Uri]$_.FullName
        $bitmap.EndInit()
        $bitmap.Freeze()
        [void]$images.Add($bitmap)
    }
    if ($images.Count -gt 0) {
        $Frames[$state] = $images
    }
}

foreach ($required in $StateAliases.Values) {
    if (-not $Frames.ContainsKey($required)) {
        [System.Windows.MessageBox]::Show("Missing animation state: $required", "lulu") | Out-Null
        exit 1
    }
}

$script:State = "idle"
$script:FrameIndex = 0
$script:IsDragging = $false
$script:DragStart = $null
$script:WindowStart = $null
$script:LastX = $null
$script:LastDirection = 0
$script:ActionName = ""
$script:ActionTicks = 0
$script:LastHourKey = ""

function Set-LuluState([string]$Alias) {
    $nextState = $Alias
    if ($StateAliases.ContainsKey($Alias)) {
        $nextState = $StateAliases[$Alias]
    }

    if ($script:State -ne $nextState) {
        $script:State = $nextState
        $script:FrameIndex = 0
    }
}

function Get-CursorScreenPoint {
    $point = New-Object LuluNativeCursor+POINT
    [LuluNativeCursor]::GetCursorPos([ref]$point) | Out-Null
    return New-Object System.Windows.Point($point.X, $point.Y)
}

function Hide-LuluText {
    $Bubble.Visibility = "Collapsed"
    $BubbleText.Visibility = "Collapsed"
}

function Show-LuluText([string]$Text) {
    $BubbleText.Text = $Text
    $Bubble.Visibility = "Visible"
    $BubbleText.Visibility = "Visible"

    $hideTimer = New-Object System.Windows.Threading.DispatcherTimer
    $hideTimer.Interval = [TimeSpan]::FromSeconds(5)
    $hideTimer.Add_Tick({
        $Bubble.Visibility = "Collapsed"
        $BubbleText.Visibility = "Collapsed"
        $this.Stop()
    })
    $hideTimer.Start()
}

function Set-StateAndSay([string]$Alias, [string]$Text) {
    Set-LuluState $Alias
    Show-LuluText $Text
}

function Start-LuluAction([string]$Name, [string]$Alias, [string]$Text, [int]$Ticks) {
    $script:ActionName = $Name
    $script:ActionTicks = $Ticks
    Set-LuluState $Alias
    if ($Text.Length -gt 0) {
        Show-LuluText $Text
    }
}

function Reset-LuluPose {
    if ($script:PetScale -ne $null) {
        $script:PetScale.ScaleX = 1
        $script:PetScale.ScaleY = 1
    }
    if ($script:PetRotate -ne $null) {
        $script:PetRotate.Angle = 0
    }
    if ($script:PetTranslate -ne $null) {
        $script:PetTranslate.X = 0
        $script:PetTranslate.Y = 0
    }
}

function Update-LuluPose {
    Reset-LuluPose
    if ($script:ActionTicks -le 0 -or $script:ActionName.Length -eq 0) {
        return
    }

    $phase = $script:ActionTicks
    switch ($script:ActionName) {
        "nod" {
            $script:PetRotate.Angle = [Math]::Sin($phase * 0.95) * 7
            $script:PetTranslate.Y = [Math]::Sin($phase * 0.95) * 4
        }
        "shake" {
            $script:PetRotate.Angle = [Math]::Sin($phase * 1.35) * 10
            $script:PetTranslate.X = [Math]::Sin($phase * 1.35) * 7
        }
        "sit" {
            $script:PetScale.ScaleX = 1.08
            $script:PetScale.ScaleY = 0.82
            $script:PetTranslate.Y = 22
        }
        "squish" {
            $script:PetScale.ScaleX = 1.14 + ([Math]::Sin($phase * 1.2) * 0.04)
            $script:PetScale.ScaleY = 0.86 - ([Math]::Sin($phase * 1.2) * 0.03)
            $script:PetTranslate.Y = 18
        }
        "peek" {
            $script:PetRotate.Angle = -8 + ([Math]::Sin($phase * 0.8) * 3)
            $script:PetTranslate.X = -10
        }
        "tiny" {
            $script:PetScale.ScaleX = 0.86
            $script:PetScale.ScaleY = 0.86
            $script:PetTranslate.Y = 18
        }
        "big" {
            $script:PetScale.ScaleX = 1.08
            $script:PetScale.ScaleY = 1.08
            $script:PetTranslate.Y = -8
        }
    }
}

function Invoke-RandomClickAction {
    $choice = Get-Random -Minimum 0 -Maximum 10
    switch ($choice) {
        0 { Start-LuluAction "jump" "jump" "Boing." 18 }
        1 { Start-LuluAction "wave" "wave" "Hi hi." 18 }
        2 { Start-LuluAction "sit" "idle" "Sitting for a second." 24 }
        3 { Start-LuluAction "shake" "waiting" "No no no." 22 }
        4 { Start-LuluAction "nod" "review" "Mm-hm." 22 }
        5 { Start-LuluAction "squish" "idle" "Squish." 20 }
        6 { Start-LuluAction "peek" "review" "I am looking." 22 }
        7 { Start-LuluAction "tiny" "failed" "Tiny lulu." 22 }
        8 { Start-LuluAction "big" "jump" "Ta-da." 18 }
        default { Start-LuluAction "blush" "waiting" "You tapped lulu." 18 }
    }
}

function Invoke-HourlyAction {
    $now = Get-Date
    $text = "It is " + $now.ToString("h:mm tt") + "."
    $choice = Get-Random -Minimum 0 -Maximum 5
    switch ($choice) {
        0 { Start-LuluAction "wave" "wave" $text 24 }
        1 { Start-LuluAction "jump" "jump" $text 22 }
        2 { Start-LuluAction "nod" "review" $text 26 }
        3 { Start-LuluAction "sit" "idle" $text 28 }
        default { Start-LuluAction "big" "waiting" $text 24 }
    }
}

$Window = New-Object System.Windows.Window
$Window.Title = "lulu desktop pet"
$Window.Width = 260
$Window.Height = 330
$Window.WindowStyle = "None"
$Window.AllowsTransparency = $true
$Window.Background = [System.Windows.Media.Brushes]::Transparent
$Window.Topmost = $true
$Window.ShowInTaskbar = $false
$Window.ResizeMode = "NoResize"
$Window.WindowStartupLocation = "Manual"
$Window.UseLayoutRounding = $true
$Window.Left = [Math]::Max(20, [System.Windows.SystemParameters]::PrimaryScreenWidth - $Window.Width - 80)
$Window.Top = [Math]::Max(20, [System.Windows.SystemParameters]::PrimaryScreenHeight - $Window.Height - 90)

$Canvas = New-Object System.Windows.Controls.Canvas
$Canvas.Width = $Window.Width
$Canvas.Height = $Window.Height
$Canvas.Background = [System.Windows.Media.Brushes]::Transparent
$Canvas.SnapsToDevicePixels = $true

$Bubble = New-Object System.Windows.Controls.Border
$Bubble.Width = 224
$Bubble.Height = 64
$Bubble.CornerRadius = "12"
$Bubble.Background = [System.Windows.Media.Brushes]::LightYellow
$Bubble.BorderBrush = [System.Windows.Media.Brushes]::Orange
$Bubble.BorderThickness = "2"
[System.Windows.Controls.Canvas]::SetLeft($Bubble, 18)
[System.Windows.Controls.Canvas]::SetTop($Bubble, 18)
$Canvas.Children.Add($Bubble) | Out-Null

$BubbleText = New-Object System.Windows.Controls.TextBlock
$BubbleText.Width = 204
$BubbleText.Text = "Hi, I am lulu"
$BubbleText.TextWrapping = "Wrap"
$BubbleText.TextAlignment = "Center"
$BubbleText.Foreground = [System.Windows.Media.Brushes]::SaddleBrown
$BubbleText.FontWeight = "Bold"
[System.Windows.Controls.Canvas]::SetLeft($BubbleText, 28)
[System.Windows.Controls.Canvas]::SetTop($BubbleText, 38)
$Canvas.Children.Add($BubbleText) | Out-Null

$PetImage = New-Object System.Windows.Controls.Image
$PetImage.Width = 192
$PetImage.Height = 208
$PetImage.Stretch = "Uniform"
$PetImage.SnapsToDevicePixels = $true
$PetImage.CacheMode = New-Object System.Windows.Media.BitmapCache
$PetImage.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.86)
$script:PetScale = New-Object System.Windows.Media.ScaleTransform
$script:PetRotate = New-Object System.Windows.Media.RotateTransform
$script:PetTranslate = New-Object System.Windows.Media.TranslateTransform
$script:PetTransforms = New-Object System.Windows.Media.TransformGroup
$script:PetTransforms.Children.Add($script:PetScale) | Out-Null
$script:PetTransforms.Children.Add($script:PetRotate) | Out-Null
$script:PetTransforms.Children.Add($script:PetTranslate) | Out-Null
$PetImage.RenderTransform = $script:PetTransforms
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($PetImage, [System.Windows.Media.BitmapScalingMode]::NearestNeighbor)
[System.Windows.Controls.Canvas]::SetLeft($PetImage, 34)
[System.Windows.Controls.Canvas]::SetTop($PetImage, 106)
$Canvas.Children.Add($PetImage) | Out-Null

$Menu = New-Object System.Windows.Controls.ContextMenu
@(
    @("Idle", { Set-StateAndSay "idle" "I am here." }),
    @("Wave", { Set-StateAndSay "wave" "Hi hi." }),
    @("Jump", { Set-StateAndSay "jump" "Jump." }),
    @("Working", { Set-StateAndSay "work" "Working carefully." }),
    @("Review", { Set-StateAndSay "review" "Let me look closely." }),
    @("Waiting", { Set-StateAndSay "waiting" "I am waiting for you." }),
    @("Random action", { Invoke-RandomClickAction }),
    @("Quit lulu", { $Window.Close() })
) | ForEach-Object {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $_[0]
    $handler = $_[1]
    $item.Add_Click($handler)
    $Menu.Items.Add($item) | Out-Null
}
$Canvas.ContextMenu = $Menu

$Canvas.Add_MouseLeftButtonDown({
    $script:IsDragging = $true
    $script:DragStart = Get-CursorScreenPoint
    $script:WindowStart = New-Object System.Windows.Point($Window.Left, $Window.Top)
    $script:LastX = $script:DragStart.X
    $script:LastDirection = 0
    $Canvas.CaptureMouse() | Out-Null
    Hide-LuluText
})

$Canvas.Add_MouseMove({
    if (-not $script:IsDragging) { return }
    $current = Get-CursorScreenPoint
    $dx = $current.X - $script:DragStart.X
    $dy = $current.Y - $script:DragStart.Y
    $nextLeft = [Math]::Round($script:WindowStart.X + $dx)
    $nextTop = [Math]::Round($script:WindowStart.Y + $dy)

    if ($Window.Left -ne $nextLeft) { $Window.Left = $nextLeft }
    if ($Window.Top -ne $nextTop) { $Window.Top = $nextTop }

    $moveDx = $current.X - $script:LastX
    $direction = 0
    if ($moveDx -ge 2) {
        $direction = 1
    } elseif ($moveDx -le -2) {
        $direction = -1
    }

    if ($direction -ne 0 -and $direction -ne $script:LastDirection) {
        if ($direction -gt 0) {
            Set-LuluState "run_right"
        } else {
            Set-LuluState "run_left"
        }
        $script:LastDirection = $direction
    }

    $script:LastX = $current.X
})

$Canvas.Add_MouseLeftButtonUp({
    if (-not $script:IsDragging) { return }
    $current = Get-CursorScreenPoint
    $totalDx = [Math]::Abs($current.X - $script:DragStart.X)
    $totalDy = [Math]::Abs($current.Y - $script:DragStart.Y)
    $wasClick = ($totalDx -le 7 -and $totalDy -le 7)

    $script:IsDragging = $false
    $Canvas.ReleaseMouseCapture()
    $script:LastDirection = 0

    if ($wasClick) {
        Invoke-RandomClickAction
    } else {
        $script:ActionName = ""
        $script:ActionTicks = 0
        Reset-LuluPose
        Set-LuluState "idle"
        $texts = @("All set.", "Nice spot.", "I am steady now.")
        Show-LuluText $texts[(Get-Random -Minimum 0 -Maximum $texts.Count)]
    }
})

$Window.Content = $Canvas

$Timer = New-Object System.Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(95)
$Timer.Add_Tick({
    $targetMs = 145
    if ($script:IsDragging -or $script:State -eq "running-right" -or $script:State -eq "running-left") {
        $targetMs = 85
    }
    if ([Math]::Abs($Timer.Interval.TotalMilliseconds - $targetMs) -gt 1) {
        $Timer.Interval = [TimeSpan]::FromMilliseconds($targetMs)
    }

    $stateFrames = $Frames[$script:State]
    $PetImage.Source = $stateFrames[$script:FrameIndex % $stateFrames.Count]
    $script:FrameIndex += 1
    Update-LuluPose

    if ($script:ActionTicks -gt 0) {
        $script:ActionTicks -= 1
        if ($script:ActionTicks -le 0) {
            $script:ActionName = ""
            Reset-LuluPose
            if (-not $script:IsDragging) {
                Set-LuluState "idle"
            }
        }
    }

    if ($script:ActionTicks -le 0 -and @("idle", "running-right", "running-left", "running") -notcontains $script:State) {
        if ($script:FrameIndex -ge ($stateFrames.Count * 2)) {
            Set-LuluState "idle"
        }
    }
})
$Timer.Start()

$IdleTimer = New-Object System.Windows.Threading.DispatcherTimer
$IdleTimer.Interval = [TimeSpan]::FromSeconds(12)
$IdleTimer.Add_Tick({
    if ($script:ActionTicks -le 0 -and $script:State -eq "idle" -and (Get-Random -Minimum 0 -Maximum 10) -lt 4) {
        $texts = @("I am with you.", "Shall we start something?", "Lulu is ready.")
        Show-LuluText $texts[(Get-Random -Minimum 0 -Maximum $texts.Count)]
    }
})
$IdleTimer.Start()

$HourTimer = New-Object System.Windows.Threading.DispatcherTimer
$HourTimer.Interval = [TimeSpan]::FromSeconds(5)
$HourTimer.Add_Tick({
    $now = Get-Date
    $hourKey = $now.ToString("yyyyMMddHH")
    if ($now.Minute -eq 0 -and $script:LastHourKey -ne $hourKey) {
        $script:LastHourKey = $hourKey
        if (-not $script:IsDragging) {
            Invoke-HourlyAction
        }
    }
})
$HourTimer.Start()

$Window.ShowDialog() | Out-Null
