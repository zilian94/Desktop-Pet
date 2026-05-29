Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class MilkDragonCursor {
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

function U([string]$hex) {
    return -join (($hex -split " ") | Where-Object { $_.Length -gt 0 } | ForEach-Object { [char][Convert]::ToInt32($_, 16) })
}

$CN = @{
    IAm = U "6211 662F 5976 9F99 3002"
    Default = U "9ED8 8BA4 5976 9F99"
    Pirate = U "6D77 76D7 8239 957F"
    Strawhat = U "7530 56ED 8349 5E3D"
    Painter = U "5C0F 753B 5BB6"
    Pilot = U "98DE 884C 5458"
    Shopper = U "8D2D 7269 8FBE 4EBA"
    Raincoat = U "96E8 8863 5957 88C5"
    Shy = U "5BB3 7F9E 8138 7EA2"
    ShyDown = U "5BB3 7F9E 4F4E 5934"
    TongueAction = U "5410 820C 52A8 4F5C"
    RandomAction = U "968F 673A 52A8 4F5C"
    Quit = U "9000 51FA 5976 9F99"
    Tongue = U "5410 820C 5934 3002"
    Changed = U "6362 88C5 5B8C 6210 3002"
    PilotTip = U "98DE 884C 5458 3002 5411 4E0A 62D6 52A8 4F1A 8D77 98DE 3002"
    TimePrefix = U "73B0 5728 662F "
    Done = U "653E 597D 5566 3002"
    TapMe = U "70B9 6211 8BD5 8BD5 3002"
    RightClick = U "53F3 952E 53EF 4EE5 6362 88C5 3002"
    PilotFlyTip = U "98DE 884C 5458 88C5 5411 4E0A 62D6 52A8 4F1A 98DE 3002"
    Here = U "5976 9F99 5728 8FD9 91CC 3002"
    DragUp = U "4E0A 8DF3 4E00 4E0B 3002"
    DragDown = U "8E72 4F4E 4E00 70B9 3002"
    DragFast = U "6447 6643 6643 3002"
}

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SpriteDir = Join-Path $AppDir "assets\sprites"

$Sprites = @{
    default = Join-Path $SpriteDir "default.png"
    pirate = Join-Path $SpriteDir "pirate.png"
    strawhat = Join-Path $SpriteDir "strawhat.png"
    painter = Join-Path $SpriteDir "painter.png"
    pilot = Join-Path $SpriteDir "pilot.png"
    shopper = Join-Path $SpriteDir "shopper.png"
    raincoat = Join-Path $SpriteDir "raincoat.png"
    tongue = Join-Path $SpriteDir "tongue.png"
    shy = Join-Path $SpriteDir "shy.png"
    shy_down = Join-Path $SpriteDir "shy_down.png"
}

foreach ($key in $Sprites.Keys) {
    if (-not (Test-Path -LiteralPath $Sprites[$key])) {
        [System.Windows.MessageBox]::Show("Missing sprite: $($Sprites[$key])", "milkdragon") | Out-Null
        exit 1
    }
}

function Load-Bitmap([string]$path) {
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.UriSource = [Uri]$path
    $bitmap.EndInit()
    $bitmap.Freeze()
    return $bitmap
}

$Bitmaps = @{}
foreach ($key in $Sprites.Keys) {
    $Bitmaps[$key] = Load-Bitmap $Sprites[$key]
}

$script:CurrentSprite = "default"
$script:Outfit = "default"
$script:ActionTicks = 0
$script:ActionName = ""
$script:Frame = 0
$script:IsDragging = $false
$script:DragStart = $null
$script:WindowStart = $null
$script:LastPoint = $null
$script:LastDirection = ""
$script:LastHourKey = ""

function Brush($hex) {
    return New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($hex))
}

function Get-CursorPoint {
    $point = New-Object MilkDragonCursor+POINT
    [MilkDragonCursor]::GetCursorPos([ref]$point) | Out-Null
    return New-Object System.Windows.Point($point.X, $point.Y)
}

function Set-Sprite([string]$name) {
    if (-not $Bitmaps.ContainsKey($name)) { return }
    $script:CurrentSprite = $name
    $PetImage.Source = $Bitmaps[$name]
}

function Reset-Pose {
    $PetScale.ScaleX = 1
    $PetScale.ScaleY = 1
    $PetRotate.Angle = 0
    $PetTranslate.X = 0
    $PetTranslate.Y = 0
}

function Hide-Bubble {
    $Bubble.Visibility = "Collapsed"
    $BubbleText.Visibility = "Collapsed"
}

function Show-Bubble([string]$text) {
    $BubbleText.Text = $text
    $Bubble.Visibility = "Visible"
    $BubbleText.Visibility = "Visible"
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(4.5)
    $timer.Add_Tick({
        $Bubble.Visibility = "Collapsed"
        $BubbleText.Visibility = "Collapsed"
        $this.Stop()
    })
    $timer.Start()
}

function Set-Outfit([string]$outfit, [string]$message = "") {
    $script:Outfit = $outfit
    $script:ActionName = ""
    $script:ActionTicks = 0
    Reset-Pose
    Set-Sprite $outfit
    if ($message.Length -gt 0) { Show-Bubble $message }
}

function Start-Action([string]$sprite, [string]$name, [int]$ticks, [string]$message = "") {
    Set-Sprite $sprite
    $script:ActionName = $name
    $script:ActionTicks = $ticks
    if ($message.Length -gt 0) { Show-Bubble $message }
}

function Invoke-RandomClickAction {
    $choices = @("tongue", "shy", "shy_down", "default", "pirate", "strawhat", "painter", "pilot", "shopper", "raincoat", "tongue")
    $sprite = $choices[(Get-Random -Minimum 0 -Maximum $choices.Count)]
    if ($sprite -ne "tongue") {
        if ($sprite -eq "shy") {
            Start-Action "shy" "shy" 42 $CN.Shy
            return
        }
        if ($sprite -eq "shy_down") {
            Start-Action "shy_down" "shy_down" 44 $CN.ShyDown
            return
        }
        $script:Outfit = $sprite
        Start-Action $sprite "pose" 36 $CN.Changed
        return
    }
    Start-Action "tongue" "bounce" 36 $CN.Tongue
}

function Invoke-HourlyTime {
    $now = Get-Date
    Start-Action $script:Outfit "nod" 36 ($CN.TimePrefix + $now.ToString("H:mm") + (U "3002"))
}

function Update-Pose {
    Reset-Pose
    $phase = $script:Frame
    if ($script:IsDragging) {
        if ($script:ActionName -eq "fly") {
            $PetTranslate.Y = -18 + [Math]::Sin($phase * 0.45) * 7
            $PetRotate.Angle = [Math]::Sin($phase * 0.35) * 4
        } elseif ($script:ActionName -eq "drag-hop") {
            $PetTranslate.Y = -15 + [Math]::Sin($phase * 0.75) * 5
            $PetScale.ScaleX = 0.97
            $PetScale.ScaleY = 1.05
        } elseif ($script:ActionName -eq "drag-duck") {
            $PetTranslate.Y = 26
            $PetScale.ScaleX = 1.08
            $PetScale.ScaleY = 0.84
            $PetRotate.Angle = [Math]::Sin($phase * 0.5) * 2
        } elseif ($script:ActionName -eq "drag-fast") {
            $PetRotate.Angle = [Math]::Sin($phase * 1.4) * 7
            $PetTranslate.X = [Math]::Sin($phase * 1.25) * 7
        } elseif ($script:LastDirection -eq "right") {
            $PetRotate.Angle = 3
            $PetTranslate.X = [Math]::Sin($phase * 0.7) * 4
        } elseif ($script:LastDirection -eq "left") {
            $PetRotate.Angle = -3
            $PetTranslate.X = [Math]::Sin($phase * 0.7) * 4
        }
        return
    }

    switch ($script:ActionName) {
        "bounce" {
            $PetTranslate.Y = -10 + [Math]::Sin($phase * 0.55) * 8
            $PetScale.ScaleX = 1.04
            $PetScale.ScaleY = 1.04
        }
        "shake" {
            $PetRotate.Angle = [Math]::Sin($phase * 1.15) * 8
            $PetTranslate.X = [Math]::Sin($phase * 1.15) * 5
        }
        "pose" {
            $PetTranslate.Y = [Math]::Sin($phase * 0.45) * 5
        }
        "wave" {
            $PetRotate.Angle = [Math]::Sin($phase * 0.5) * 5
        }
        "nod" {
            $PetTranslate.Y = [Math]::Sin($phase * 0.8) * 5
        }
        "shy" {
            $PetTranslate.Y = [Math]::Sin($phase * 0.35) * 3
            $PetRotate.Angle = [Math]::Sin($phase * 0.3) * 2
        }
        "shy_down" {
            $PetTranslate.Y = 10 + [Math]::Sin($phase * 0.35) * 2
            $PetScale.ScaleX = 1.03
            $PetScale.ScaleY = 0.96
        }
    }
}

$Window = New-Object System.Windows.Window
$Window.Title = "milkdragon desktop pet"
$Window.Width = 340
$Window.Height = 430
$Window.WindowStyle = "None"
$Window.AllowsTransparency = $true
$Window.Background = [System.Windows.Media.Brushes]::Transparent
$Window.Topmost = $true
$Window.ShowInTaskbar = $false
$Window.ResizeMode = "NoResize"
$Window.WindowStartupLocation = "Manual"
$Window.UseLayoutRounding = $true
$Window.Left = [Math]::Max(20, [System.Windows.SystemParameters]::PrimaryScreenWidth - $Window.Width - 90)
$Window.Top = [Math]::Max(20, [System.Windows.SystemParameters]::PrimaryScreenHeight - $Window.Height - 90)

$Canvas = New-Object System.Windows.Controls.Canvas
$Canvas.Width = $Window.Width
$Canvas.Height = $Window.Height
$Canvas.Background = [System.Windows.Media.Brushes]::Transparent
$Canvas.SnapsToDevicePixels = $true

$Bubble = New-Object System.Windows.Controls.Border
$Bubble.Width = 276
$Bubble.Height = 58
$Bubble.CornerRadius = "14"
$Bubble.Background = Brush "#fff7d8"
$Bubble.BorderBrush = Brush "#f6a53d"
$Bubble.BorderThickness = "2"
[System.Windows.Controls.Canvas]::SetLeft($Bubble, 32)
[System.Windows.Controls.Canvas]::SetTop($Bubble, 18)
$Canvas.Children.Add($Bubble) | Out-Null

$BubbleText = New-Object System.Windows.Controls.TextBlock
$BubbleText.Width = 250
$BubbleText.Text = $CN.IAm
$BubbleText.TextWrapping = "Wrap"
$BubbleText.TextAlignment = "Center"
$BubbleText.Foreground = Brush "#5f3800"
$BubbleText.FontWeight = "Bold"
[System.Windows.Controls.Canvas]::SetLeft($BubbleText, 45)
[System.Windows.Controls.Canvas]::SetTop($BubbleText, 37)
$Canvas.Children.Add($BubbleText) | Out-Null

$PetImage = New-Object System.Windows.Controls.Image
$PetImage.Width = 320
$PetImage.Height = 320
$PetImage.Stretch = "Uniform"
$PetImage.SnapsToDevicePixels = $true
$PetImage.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.86)
$PetScale = New-Object System.Windows.Media.ScaleTransform
$PetRotate = New-Object System.Windows.Media.RotateTransform
$PetTranslate = New-Object System.Windows.Media.TranslateTransform
$PetGroup = New-Object System.Windows.Media.TransformGroup
$PetGroup.Children.Add($PetScale) | Out-Null
$PetGroup.Children.Add($PetRotate) | Out-Null
$PetGroup.Children.Add($PetTranslate) | Out-Null
$PetImage.RenderTransform = $PetGroup
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($PetImage, [System.Windows.Media.BitmapScalingMode]::HighQuality)
[System.Windows.Controls.Canvas]::SetLeft($PetImage, 10)
[System.Windows.Controls.Canvas]::SetTop($PetImage, 92)
$Canvas.Children.Add($PetImage) | Out-Null

$Menu = New-Object System.Windows.Controls.ContextMenu
@(
    @($CN.Default, { Set-Outfit "default" ($CN.Default + (U "3002")) }),
    @($CN.Pirate, { Set-Outfit "pirate" ($CN.Pirate + (U "3002")) }),
    @($CN.Strawhat, { Set-Outfit "strawhat" ($CN.Strawhat + (U "3002")) }),
    @($CN.Painter, { Set-Outfit "painter" ($CN.Painter + (U "3002")) }),
    @($CN.Pilot, { Set-Outfit "pilot" $CN.PilotTip }),
    @($CN.Shopper, { Set-Outfit "shopper" ($CN.Shopper + (U "3002")) }),
    @($CN.Raincoat, { Set-Outfit "raincoat" ($CN.Raincoat + (U "3002")) }),
    @($CN.Shy, { Start-Action "shy" "shy" 42 $CN.Shy }),
    @($CN.ShyDown, { Start-Action "shy_down" "shy_down" 44 $CN.ShyDown }),
    @($CN.TongueAction, { Start-Action "tongue" "bounce" 36 $CN.Tongue }),
    @($CN.RandomAction, { Invoke-RandomClickAction }),
    @($CN.Quit, { $Window.Close() })
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
    $script:DragStart = Get-CursorPoint
    $script:WindowStart = New-Object System.Windows.Point($Window.Left, $Window.Top)
    $script:LastPoint = $script:DragStart
    $script:LastDirection = ""
    Hide-Bubble
    $Canvas.CaptureMouse() | Out-Null
})

$Canvas.Add_MouseMove({
    if (-not $script:IsDragging) { return }
    $current = Get-CursorPoint
    $dx = $current.X - $script:DragStart.X
    $dy = $current.Y - $script:DragStart.Y
    $Window.Left = [Math]::Round($script:WindowStart.X + $dx)
    $Window.Top = [Math]::Round($script:WindowStart.Y + $dy)

    $moveX = $current.X - $script:LastPoint.X
    $moveY = $current.Y - $script:LastPoint.Y
    $direction = ""
    $speed = [Math]::Sqrt(($moveX * $moveX) + ($moveY * $moveY))
    if ($moveY -le -4 -and $script:Outfit -eq "pilot") {
        $direction = "up"
    } elseif ($moveY -le -4) {
        $direction = "up-hop"
    } elseif ($speed -ge 18) {
        $direction = "fast"
    } elseif ($moveY -ge 5) {
        $direction = "down"
    } elseif ($moveX -ge 2) {
        $direction = "right"
    } elseif ($moveX -le -2) {
        $direction = "left"
    }

    if ($direction.Length -gt 0 -and $direction -ne $script:LastDirection) {
        if ($direction -eq "up") {
            Set-Sprite "pilot"
            $script:ActionName = "fly"
        } elseif ($direction -eq "up-hop") {
            Set-Sprite $script:Outfit
            $script:ActionName = "drag-hop"
        } elseif ($direction -eq "down") {
            Set-Sprite $script:Outfit
            $script:ActionName = "drag-duck"
        } elseif ($direction -eq "fast") {
            Set-Sprite $script:Outfit
            $script:ActionName = "drag-fast"
        } elseif ($script:Outfit -ne "default") {
            Set-Sprite $script:Outfit
            $script:ActionName = ""
        } else {
            Set-Sprite "default"
            $script:ActionName = ""
        }
        $script:LastDirection = $direction
    }
    $script:LastPoint = $current
})

$Canvas.Add_MouseLeftButtonUp({
    if (-not $script:IsDragging) { return }
    $current = Get-CursorPoint
    $totalDx = [Math]::Abs($current.X - $script:DragStart.X)
    $totalDy = [Math]::Abs($current.Y - $script:DragStart.Y)
    $wasClick = ($totalDx -le 7 -and $totalDy -le 7)

    $script:IsDragging = $false
    $Canvas.ReleaseMouseCapture()
    $script:LastDirection = ""
    Reset-Pose

    if ($wasClick) {
        Invoke-RandomClickAction
    } else {
        $script:ActionName = ""
        $script:ActionTicks = 0
        Set-Sprite $script:Outfit
        Show-Bubble $CN.Done
    }
})

$Window.Content = $Canvas
Set-Sprite "default"

$Timer = New-Object System.Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(75)
$Timer.Add_Tick({
    $script:Frame += 1
    Update-Pose
    if ($script:ActionTicks -gt 0) {
        $script:ActionTicks -= 1
        if ($script:ActionTicks -le 0 -and -not $script:IsDragging) {
            $script:ActionName = ""
            Reset-Pose
            Set-Sprite $script:Outfit
        }
    }
})
$Timer.Start()

$HourTimer = New-Object System.Windows.Threading.DispatcherTimer
$HourTimer.Interval = [TimeSpan]::FromSeconds(5)
$HourTimer.Add_Tick({
    $now = Get-Date
    $key = $now.ToString("yyyyMMddHH")
    if ($now.Minute -eq 0 -and $script:LastHourKey -ne $key) {
        $script:LastHourKey = $key
        if (-not $script:IsDragging) {
            Invoke-HourlyTime
        }
    }
})
$HourTimer.Start()

$IdleTimer = New-Object System.Windows.Threading.DispatcherTimer
$IdleTimer.Interval = [TimeSpan]::FromSeconds(14)
$IdleTimer.Add_Tick({
    if (-not $script:IsDragging -and $script:ActionTicks -le 0 -and (Get-Random -Minimum 0 -Maximum 10) -lt 3) {
        $messages = @($CN.TapMe, $CN.RightClick, $CN.PilotFlyTip, $CN.Here)
        Show-Bubble $messages[(Get-Random -Minimum 0 -Maximum $messages.Count)]
    }
})
$IdleTimer.Start()

$Window.ShowDialog() | Out-Null
