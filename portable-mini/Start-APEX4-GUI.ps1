$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

$root = $PSScriptRoot
$bridge = Join-Path $root "ApexSenseBridge.exe"
$launcher = Join-Path $root "Start-APEX4-Mini.ps1"
$settingsPath = Join-Path $root "APEX4-GUI.settings.json"
$script:bridgeProcess = $null
$script:exiting = $false

function Load-Settings {
    $defaults = [pscustomobject]@{ TriggerStrength = 100; RumbleStrength = 100 }
    try {
        if (Test-Path -LiteralPath $settingsPath) {
            $loaded = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            $defaults.TriggerStrength = [Math]::Max(0, [Math]::Min(200, [int]$loaded.TriggerStrength))
            $defaults.RumbleStrength = [Math]::Max(0, [Math]::Min(200, [int]$loaded.RumbleStrength))
        }
    } catch {}
    return $defaults
}

function Save-Settings {
    [pscustomobject]@{
        TriggerStrength = [int]$triggerSlider.Value
        RumbleStrength = [int]$rumbleSlider.Value
    } | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="APEX4 DualSense Bridge" Width="470" Height="430"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#111827" Foreground="#F9FAFB" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#2563EB"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="22,10"/>
      <Setter Property="Margin" Value="0,0,10,0"/><Setter Property="FontSize" Value="14"/>
    </Style>
    <Style TargetType="Slider"><Setter Property="Margin" Value="0,8,0,4"/></Style>
  </Window.Resources>
  <Grid Margin="24">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
    <StackPanel Grid.Row="0">
      <TextBlock Text="APEX4 DualSense Bridge" FontSize="23" FontWeight="SemiBold"/>
      <TextBlock Text="实体 Xbox 隐藏 · 虚拟 DualSense · 自适应扳机 · 振动" Foreground="#9CA3AF" Margin="0,6,0,18"/>
    </StackPanel>
    <Border Grid.Row="1" Background="#1F2937" CornerRadius="9" Padding="16" Margin="0,0,0,14">
      <DockPanel><Ellipse x:Name="StatusDot" Width="10" Height="10" Fill="#6B7280" Margin="0,0,10,0"/>
        <TextBlock x:Name="StatusText" Text="已停止，HidHide 已还原" FontSize="14"/></DockPanel>
    </Border>
    <StackPanel Grid.Row="2" Margin="0,0,0,14">
      <DockPanel><TextBlock Text="自适应扳机强度" FontSize="14"/><TextBlock x:Name="TriggerValue" Text="100%" DockPanel.Dock="Right" HorizontalAlignment="Right" Foreground="#60A5FA"/></DockPanel>
      <Slider x:Name="TriggerSlider" Minimum="0" Maximum="200" TickFrequency="10" IsSnapToTickEnabled="True"/>
      <DockPanel Margin="0,12,0,0"><TextBlock Text="振动强度" FontSize="14"/><TextBlock x:Name="RumbleValue" Text="100%" DockPanel.Dock="Right" HorizontalAlignment="Right" Foreground="#60A5FA"/></DockPanel>
      <Slider x:Name="RumbleSlider" Minimum="0" Maximum="200" TickFrequency="10" IsSnapToTickEnabled="True"/>
      <TextBlock Text="强度修改会在下一次启动时生效" Foreground="#9CA3AF" FontSize="11" Margin="0,5,0,0"/>
    </StackPanel>
    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,2,0,12">
      <Button x:Name="StartButton" Content="启动" Width="120"/>
      <Button x:Name="StopButton" Content="停止" Width="120" Background="#DC2626" IsEnabled="False"/>
      <Button x:Name="HideButton" Content="最小化到托盘" Width="150" Background="#374151"/>
    </StackPanel>
    <TextBlock Grid.Row="4" TextWrapping="Wrap" Foreground="#9CA3AF" FontSize="11.5"
      Text="启动后 HidHide 临时隐藏 Xbox 360 Controller，游戏只看到虚拟 DualSense。停止或从托盘退出时会自动恢复 HidHide 原配置。"/>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$triggerSlider = $window.FindName("TriggerSlider")
$rumbleSlider = $window.FindName("RumbleSlider")
$triggerValue = $window.FindName("TriggerValue")
$rumbleValue = $window.FindName("RumbleValue")
$startButton = $window.FindName("StartButton")
$stopButton = $window.FindName("StopButton")
$hideButton = $window.FindName("HideButton")
$statusText = $window.FindName("StatusText")
$statusDot = $window.FindName("StatusDot")

$settings = Load-Settings
$triggerSlider.Value = $settings.TriggerStrength
$rumbleSlider.Value = $settings.RumbleStrength
$triggerValue.Text = ([int]$triggerSlider.Value).ToString() + "%"
$rumbleValue.Text = ([int]$rumbleSlider.Value).ToString() + "%"

function Set-UiState([bool]$running, [string]$text) {
    $statusText.Text = $text
    $statusDot.Fill = if ($running) { [Windows.Media.Brushes]::LimeGreen } else { [Windows.Media.Brushes]::Gray }
    $startButton.IsEnabled = -not $running
    $stopButton.IsEnabled = $running
    $triggerSlider.IsEnabled = -not $running
    $rumbleSlider.IsEnabled = -not $running
}

function Start-Bridge {
    if ($script:bridgeProcess -and -not $script:bridgeProcess.HasExited) { return }
    if (-not (Test-Path -LiteralPath $bridge) -or -not (Test-Path -LiteralPath $launcher)) {
        [System.Windows.MessageBox]::Show("便携包文件不完整，请重新解压。", "APEX4 Bridge") | Out-Null
        return
    }
    Save-Settings
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ('"' + $launcher + '"'),
              "-TriggerStrength", [string][int]$triggerSlider.Value,
              "-RumbleStrength", [string][int]$rumbleSlider.Value)
    $script:bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -PassThru
    Set-UiState $true "正在启动并配置 HidHide…"
}

function Stop-Bridge {
    if (Test-Path -LiteralPath $bridge) {
        try { & $bridge stop-active-sessions | Out-Null } catch {}
    }
    Set-UiState $false "正在停止并还原 HidHide…"
}

$triggerSlider.Add_ValueChanged({ $triggerValue.Text = ([int]$triggerSlider.Value).ToString() + "%" })
$rumbleSlider.Add_ValueChanged({ $rumbleValue.Text = ([int]$rumbleSlider.Value).ToString() + "%" })
$startButton.Add_Click({ Start-Bridge })
$stopButton.Add_Click({ Stop-Bridge })
$hideButton.Add_Click({ $window.Hide() })

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({
    if ($script:bridgeProcess) {
        $script:bridgeProcess.Refresh()
        if ($script:bridgeProcess.HasExited) {
            $script:bridgeProcess.Dispose()
            $script:bridgeProcess = $null
            Set-UiState $false "已停止，HidHide 已还原"
        } elseif ($statusText.Text -like "正在启动*") {
            $statusText.Text = "运行中：Xbox 360 已隐藏"
        }
    }
})
$timer.Start()

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Text = "APEX4 DualSense Bridge"
$tray.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $PID).Path)
$tray.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add("打开界面", $null, { $window.Show(); $window.WindowState = "Normal"; $window.Activate() })
[void]$menu.Items.Add("启动", $null, { $window.Dispatcher.Invoke([action]{ Start-Bridge }) })
[void]$menu.Items.Add("停止并还原 HidHide", $null, { $window.Dispatcher.Invoke([action]{ Stop-Bridge }) })
[void]$menu.Items.Add("退出", $null, { $window.Dispatcher.Invoke([action]{ $script:exiting = $true; Stop-Bridge; $window.Close() }) })
$tray.ContextMenuStrip = $menu
$tray.Add_DoubleClick({ $window.Show(); $window.WindowState = "Normal"; $window.Activate() })

$window.Add_StateChanged({ if ($window.WindowState -eq "Minimized") { $window.Hide() } })
$window.Add_Closing({ param($sender, $eventArgs)
    if (-not $script:exiting) { $eventArgs.Cancel = $true; $window.Hide(); return }
    Stop-Bridge
    if ($script:bridgeProcess) {
        try { $script:bridgeProcess.WaitForExit(15000) } catch {}
    }
    $tray.Visible = $false
    $tray.Dispose()
    $menu.Dispose()
    Save-Settings
})

[void]$window.ShowDialog()
