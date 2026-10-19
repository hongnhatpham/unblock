# Unblock: a small window to switch GoodbyeDPI on/off and edit which sites it unblocks.
# Launch with Unblock.vbs (no console flash). Needs install.ps1 to have run once (the app offers it).
# Closing or minimizing hides it to the tray; -Tray starts it there (used when starting with Windows).
param([switch]$Tray)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

$Root = $PSScriptRoot
$SitesFile = Join-Path $Root 'sites.txt'
$IconFile = Join-Path $Root 'unblock.ico'
$Service = 'GoodbyeDPI'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

# One copy at a time. Opening it again tells the running copy to show its window.
$mutex = New-Object System.Threading.Mutex($false, 'Local\HongUnblockApp')
$showSignal = New-Object System.Threading.EventWaitHandle($false, 'AutoReset', 'Local\HongUnblockShow')
if (-not $mutex.WaitOne(0)) { [void]$showSignal.Set(); exit }

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class Win {
  [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
  [DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string id);
}
'@
[void][Win]::SetCurrentProcessExplicitAppUserModelID('Hong.Unblock')

# ---------- Theme: follow Windows light/dark mode and accent colour ----------
$personalize = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue
$dark = $personalize -and $personalize.AppsUseLightTheme -eq 0
$accent = '#0067C0'
$dwm = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction SilentlyContinue
if ($dwm -and $dwm.AccentColor) {
  $c = [uint32]($dwm.AccentColor -band 0xFFFFFFFF) # stored as ABGR
  $accent = '#{0:X2}{1:X2}{2:X2}' -f ($c -band 0xFF), (($c -shr 8) -band 0xFF), (($c -shr 16) -band 0xFF)
}
$P = if ($dark) {
  @{ Bg = '#202020'; Card = '#2B2B2B'; Stroke = '#3A3A3A'; Text = '#F3F3F3'; Sub = '#A3A3A3'; Hover = '#353535'; Field = '#1F1F1F'; Accent = $accent; Good = '#6CCB5F'; Warn = '#FCE100' }
} else {
  @{ Bg = '#F3F3F3'; Card = '#FFFFFF'; Stroke = '#E3E3E3'; Text = '#1A1A1A'; Sub = '#5F5F5F'; Hover = '#F5F5F5'; Field = '#FFFFFF'; Accent = $accent; Good = '#0F7B0F'; Warn = '#9D5D00' }
}

# ---------- Layout ----------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Unblock" Width="420" Height="560" MinWidth="360" MinHeight="420"
        WindowStartupLocation="CenterScreen" Background="$($P.Bg)"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="14" Foreground="$($P.Text)"
        TextOptions.TextFormattingMode="Display" UseLayoutRounding="True">
  <Window.Resources>
    <Style x:Key="Switch" TargetType="ToggleButton">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="ToggleButton">
          <Border x:Name="Track" Width="44" Height="22" CornerRadius="11" Background="Transparent"
                  BorderBrush="$($P.Sub)" BorderThickness="1">
            <Ellipse x:Name="Knob" Width="12" Height="12" Fill="$($P.Sub)" HorizontalAlignment="Left" Margin="4,0,0,0">
              <Ellipse.RenderTransform><TranslateTransform X="0"/></Ellipse.RenderTransform>
            </Ellipse>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="Track" Property="Background" Value="$($P.Accent)"/>
              <Setter TargetName="Track" Property="BorderBrush" Value="$($P.Accent)"/>
              <Setter TargetName="Knob" Property="Fill" Value="White"/>
              <Trigger.EnterActions><BeginStoryboard><Storyboard>
                <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="22" Duration="0:0:0.2">
                  <DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction>
                </DoubleAnimation>
                <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="Width" To="14" Duration="0:0:0.2"/>
                <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="Height" To="14" Duration="0:0:0.2"/>
              </Storyboard></BeginStoryboard></Trigger.EnterActions>
              <Trigger.ExitActions><BeginStoryboard><Storyboard>
                <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="0" Duration="0:0:0.2">
                  <DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction>
                </DoubleAnimation>
                <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="Width" To="12" Duration="0:0:0.2"/>
                <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="Height" To="12" Duration="0:0:0.2"/>
              </Storyboard></BeginStoryboard></Trigger.ExitActions>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Background" Value="$($P.Accent)"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="B" Background="{TemplateBinding Background}" CornerRadius="6" Padding="16,0">
            <ContentPresenter VerticalAlignment="Center" HorizontalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.9"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.8"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Opacity" Value="0.5"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Link" TargetType="Button">
      <Setter Property="Foreground" Value="$($P.Accent)"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <TextBlock x:Name="T" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" FontWeight="SemiBold"/>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="T" Property="TextDecorations" Value="Underline"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Remove" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="ToolTip" Value="Remove"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="B" Width="28" Height="28" CornerRadius="4" Background="Transparent">
            <TextBlock Text="&#xE711;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11"
                       Foreground="$($P.Sub)" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="$($P.Stroke)"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="$($P.Card)" BorderBrush="$($P.Stroke)" BorderThickness="1" CornerRadius="8">
      <StackPanel>
        <Grid Margin="18,16">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel VerticalAlignment="Center">
            <TextBlock x:Name="StateTitle" Text="Off" FontSize="20" FontWeight="SemiBold" FontFamily="Segoe UI Variable Display, Segoe UI"/>
            <TextBlock x:Name="StateSub" Text="" Foreground="$($P.Sub)" Margin="0,2,0,0" TextWrapping="Wrap"/>
          </StackPanel>
          <ToggleButton x:Name="Power" Grid.Column="1" Style="{StaticResource Switch}" VerticalAlignment="Center" Margin="16,0,0,0"/>
        </Grid>
        <Border Height="1" Background="$($P.Stroke)"/>
        <Grid Margin="18,12">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock Text="Start with Windows" VerticalAlignment="Center"/>
          <ToggleButton x:Name="Startup" Grid.Column="1" Style="{StaticResource Switch}" VerticalAlignment="Center" Margin="16,0,0,0"/>
        </Grid>
      </StackPanel>
    </Border>

    <TextBlock Grid.Row="1" Text="Sites" FontWeight="SemiBold" Margin="2,22,0,8"/>

    <Border Grid.Row="2" Background="$($P.Card)" BorderBrush="$($P.Stroke)" BorderThickness="1" CornerRadius="8">
      <Grid>
        <ListBox x:Name="Sites" Background="Transparent" BorderThickness="0" Padding="4"
                 ScrollViewer.HorizontalScrollBarVisibility="Disabled" Foreground="$($P.Text)">
          <ListBox.ItemContainerStyle>
            <Style TargetType="ListBoxItem">
              <Setter Property="Template"><Setter.Value>
                <ControlTemplate TargetType="ListBoxItem">
                  <Border x:Name="Row" CornerRadius="4" Padding="12,4,4,4" Background="Transparent">
                    <ContentPresenter/>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="$($P.Hover)"/></Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
              </Setter.Value></Setter>
            </Style>
          </ListBox.ItemContainerStyle>
          <ListBox.ItemTemplate>
            <DataTemplate>
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <TextBlock Text="{Binding}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                <Button Grid.Column="1" Style="{StaticResource Remove}" Tag="{Binding}"/>
              </Grid>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
        <TextBlock x:Name="Empty" Text="No sites yet. Add one below." Foreground="$($P.Sub)"
                   HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
      </Grid>
    </Border>

    <Grid Grid.Row="3" Margin="0,12,0,0">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <Border x:Name="FieldBorder" Background="$($P.Field)" BorderBrush="$($P.Stroke)" BorderThickness="1" CornerRadius="6" Height="36">
        <Grid>
          <TextBox x:Name="Input" Background="Transparent" BorderThickness="0" Foreground="$($P.Text)" CaretBrush="$($P.Text)"
                   VerticalContentAlignment="Center" Padding="8,0"/>
          <TextBlock x:Name="Placeholder" Text="Add a site, like example.com" Foreground="$($P.Sub)"
                     IsHitTestVisible="False" VerticalAlignment="Center" Margin="12,0"/>
        </Grid>
      </Border>
      <Button x:Name="Add" Grid.Column="1" Content="Add" Style="{StaticResource Btn}" Height="36" Margin="8,0,0,0" IsDefault="True"/>
    </Grid>

    <StackPanel Grid.Row="4" Margin="2,10,0,0" MinHeight="40">
      <TextBlock x:Name="Message" Foreground="$($P.Sub)" TextWrapping="Wrap"/>
      <Button x:Name="AddAnyway" Content="Add anyway" Style="{StaticResource Link}" HorizontalAlignment="Left" Margin="0,4,0,0" Visibility="Collapsed"/>
    </StackPanel>
  </Grid>
</Window>
"@

$win = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($n in 'StateTitle', 'StateSub', 'Power', 'Startup', 'Sites', 'Empty', 'Input', 'Placeholder', 'FieldBorder', 'Add', 'Message', 'AddAnyway') { $ui[$n] = $win.FindName($n) }
if (Test-Path $IconFile) { try { $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$IconFile) } catch {} }
$win.Add_SourceInitialized({
  $h = (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
  $v = [int]$dark; [void][Win]::DwmSetWindowAttribute($h, 20, [ref]$v, 4) # dark title bar
})
$brush = { param($hex) [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

# ---------- Background work without freezing the window ----------
$script:jobs = New-Object System.Collections.ArrayList
function Start-Work([scriptblock]$work, $arg, [scriptblock]$done) {
  $ps = [powershell]::Create().AddScript($work.ToString()).AddArgument($arg)
  [void]$script:jobs.Add(@{ ps = $ps; handle = $ps.BeginInvoke(); done = $done })
}
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(80)
$timer.Add_Tick({
  foreach ($j in @($script:jobs)) {
    if ($j.handle.IsCompleted) {
      $script:jobs.Remove($j)
      $result = try { $j.ps.EndInvoke($j.handle) | Select-Object -Last 1 } catch { "error: $($_.Exception.Message)" }
      $j.ps.Dispose()
      & $j.done $result
    }
  }
  if ($showSignal.WaitOne(0)) { Show-Window }
  # Keep the tray icon in sync if the service changes elsewhere (about every 3 seconds).
  if ((++$script:ticks % 40) -eq 0 -and -not $script:jobs.Count) { Update-Tray (Get-State) }
})
$script:ticks = 0
$timer.Start()

# ---------- Tray: closing or minimizing hides the window here ----------
# The .ico holds PNG images, which System.Drawing can't read, so decode the 32px one with WPF.
$trayBitmap = try {
  $frame = [Windows.Media.Imaging.BitmapDecoder]::Create([Uri]$IconFile, 'None', 'OnLoad').Frames |
    Sort-Object { [math]::Abs($_.PixelWidth - 32) } | Select-Object -First 1
  $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($frame))
  $ms = New-Object System.IO.MemoryStream; $enc.Save($ms)
  New-Object System.Drawing.Bitmap $ms
} catch { [System.Drawing.SystemIcons]::Application.ToBitmap() }
$iconOn = [System.Drawing.Icon]::FromHandle($trayBitmap.GetHicon())
$iconOff = & {
  # Grey copy of the icon for when unblocking is off.
  $src = $trayBitmap; $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height
  $m = New-Object System.Drawing.Imaging.ColorMatrix (, [single[][]](
      [single[]](0.3, 0.3, 0.3, 0, 0), [single[]](0.59, 0.59, 0.59, 0, 0), [single[]](0.11, 0.11, 0.11, 0, 0),
      [single[]](0, 0, 0, 0.8, 0), [single[]](0, 0, 0, 0, 1)))
  $attr = New-Object System.Drawing.Imaging.ImageAttributes; $attr.SetColorMatrix($m)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $src.Width, $src.Height), 0, 0, $src.Width, $src.Height, 'Pixel', $attr)
  $g.Dispose()
  [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = $iconOff; $trayIcon.Text = 'Unblock'; $trayIcon.Visible = $true
# Tray menu in the app's colours (the default WinForms menu is a dated white box).
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System.Drawing; using System.Windows.Forms;
public class MenuColors : ProfessionalColorTable {
  Color bg, hover, line;
  public MenuColors(Color bg, Color hover, Color line) { this.bg = bg; this.hover = hover; this.line = line; UseSystemColors = false; }
  public override Color ToolStripDropDownBackground { get { return bg; } }
  public override Color ImageMarginGradientBegin { get { return bg; } }
  public override Color ImageMarginGradientMiddle { get { return bg; } }
  public override Color ImageMarginGradientEnd { get { return bg; } }
  public override Color MenuBorder { get { return line; } }
  public override Color MenuItemBorder { get { return hover; } }
  public override Color MenuItemSelected { get { return hover; } }
  public override Color SeparatorDark { get { return line; } }
  public override Color SeparatorLight { get { return bg; } }
}
'@
$color = { param($hex) [System.Drawing.ColorTranslator]::FromHtml($hex) }
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer (New-Object MenuColors (& $color $P.Card), (& $color $P.Hover), (& $color $P.Stroke))
$menu.Font = New-Object System.Drawing.Font 'Segoe UI', 9.5
$menu.ShowImageMargin = $false
$menu.Padding = New-Object System.Windows.Forms.Padding 4
$menuOpen = $menu.Items.Add('Open Unblock'); $menuOpen.Font = New-Object System.Drawing.Font $menu.Font, ([System.Drawing.FontStyle]::Bold)
$menuPower = $menu.Items.Add('Turn off')
[void]$menu.Items.Add('-')
$menuQuit = $menu.Items.Add('Quit')
foreach ($item in $menu.Items) { $item.ForeColor = & $color $P.Text; $item.Padding = New-Object System.Windows.Forms.Padding 8, 4, 8, 4 }
$trayIcon.ContextMenuStrip = $menu

function Update-Tray([string]$state) {
  $trayIcon.Icon = if ($state -eq 'on') { $iconOn } else { $iconOff }
  $trayIcon.Text = switch ($state) { 'on' { 'Unblock: on' } 'off' { 'Unblock: off' } default { 'Unblock: not set up' } }
  $menuPower.Text = if ($state -eq 'on') { 'Turn off' } else { 'Turn on' }
  $menuPower.Enabled = $state -ne 'missing' -and -not $script:jobs.Count
}
function Show-Window {
  $win.Show()
  if ($win.WindowState -eq 'Minimized') { $win.WindowState = 'Normal' }
  [void]$win.Activate()
  $win.Topmost = $true; $win.Topmost = $false # bring to front over other apps
  Show-State (Get-State) ''
}
function Hide-Window {
  $win.Hide()
  # Explain the tray once, the first time the window goes away.
  $flag = 'HKCU:\Software\HongUnblock'
  if (-not (Get-ItemProperty $flag -Name TrayHint -ErrorAction SilentlyContinue)) {
    [void](New-Item $flag -Force); Set-ItemProperty $flag TrayHint 1
    $trayIcon.ShowBalloonTip(4000, 'Unblock is still running', 'Find it in the tray. Right-click the icon to quit.', 'None')
  }
}
function Exit-App {
  $script:quitting = $true
  $trayIcon.Visible = $false; $trayIcon.Dispose()
  $app.Shutdown()
}

$trayIcon.Add_MouseClick({ if ($_.Button -eq 'Left') { Show-Window } })
$menuOpen.Add_Click({ Show-Window })
$menuPower.Add_Click({ if ((Get-State) -eq 'on') { Set-Power 'off' 'Turning off...' } else { Set-Power 'on' 'Turning on...' } })
$menuQuit.Add_Click({ Exit-App })
$win.Add_Closing({ if (-not $script:quitting) { $_.Cancel = $true; Hide-Window } })
# Stay minimized while hidden; Show-Window restores it. (Restoring while hidden leaves the window off screen.)
$win.Add_StateChanged({ if ($win.WindowState -eq 'Minimized') { Hide-Window } })

# ---------- Start with Windows: opens Unblock in the tray at sign-in and starts unblocking ----------
function Get-Startup { [bool](Get-ItemProperty $RunKey -Name Unblock -ErrorAction SilentlyContinue) }
$ui.Startup.Add_Click({
  $on = [bool]$ui.Startup.IsChecked
  sc.exe config $Service start= $(if ($on) { 'auto' } else { 'demand' }) | Out-Null
  if ($LASTEXITCODE) {
    $ui.Startup.IsChecked = Get-Startup
    Set-Message 'Could not change this. Run install.ps1 again to give the app permission.' 'warn'
    return
  }
  if ($on) { Set-ItemProperty $RunKey Unblock "`"$env:WINDIR\System32\wscript.exe`" `"$Root\Unblock.vbs`" -Tray" }
  else { Remove-ItemProperty $RunKey -Name Unblock -ErrorAction SilentlyContinue }
})

# ---------- Service ----------
$serviceWork = {
  param($action) # 'on' | 'off' | 'restart'
  $name = 'GoodbyeDPI'
  function WaitFor($status) { for ($i = 0; $i -lt 50; $i++) { if ((Get-Service $name).Status -eq $status) { return }; Start-Sleep -Milliseconds 200 } }
  if ($action -in 'off', 'restart') { sc.exe stop $name | Out-Null; WaitFor 'Stopped' }
  if ($action -in 'on', 'restart') { sc.exe start $name | Out-Null; WaitFor 'Running' }
  (Get-Service $name).Status.ToString()
}
function Get-State {
  $s = Get-Service $Service -ErrorAction SilentlyContinue
  if (-not $s) { 'missing' } elseif ($s.Status -eq 'Running') { 'on' } else { 'off' }
}

function Show-State([string]$state, [string]$busy) {
  $count = $ui.Sites.Items.Count
  $sitesWord = if ($count -eq 1) { '1 site' } else { "$count sites" }
  $ui.Power.IsEnabled = -not $busy
  if ($busy) { $ui.StateSub.Text = $busy; return }
  switch ($state) {
    'on' { $ui.Power.IsChecked = $true; $ui.StateTitle.Text = 'On'; $ui.StateSub.Text = "Unblocking $sitesWord." }
    'off' { $ui.Power.IsChecked = $false; $ui.StateTitle.Text = 'Off'; $ui.StateSub.Text = "Blocked sites won't load." }
    default { $ui.Power.IsChecked = $false; $ui.StateTitle.Text = 'Not set up'; $ui.StateSub.Text = 'Turn on to set it up. Windows will ask for permission once.' }
  }
  $ui.Startup.IsEnabled = $state -ne 'missing'
  Update-Tray $state
}

function Set-Power([string]$action, [string]$busyText) {
  Show-State '' $busyText
  Start-Work $serviceWork $action { param($r) Show-State (Get-State) '' }
}

$ui.Power.Add_Click({
  $state = Get-State
  if ($state -eq 'missing') {
    Show-State '' 'Setting up...'
    # install.ps1 asks Windows for admin permission itself.
    try { Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $Root 'install.ps1')`"" -Wait -WindowStyle Hidden } catch {}
    Show-State (Get-State) ''
  } elseif ($ui.Power.IsChecked) { Set-Power 'on' 'Turning on...' }
  else { Set-Power 'off' 'Turning off...' }
})

# ---------- Sites ----------
function Read-Sites {
  if (-not (Test-Path $SitesFile)) { Copy-Item (Join-Path $Root 'sites.default.txt') $SitesFile -ErrorAction SilentlyContinue }
  if (-not (Test-Path $SitesFile)) { return @() }
  @(Get-Content $SitesFile | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -and -not $_.StartsWith('#') } | Select-Object -Unique)
}
function Show-Sites {
  $ui.Sites.Items.Clear()
  foreach ($s in Read-Sites | Sort-Object) { [void]$ui.Sites.Items.Add($s) }
  $ui.Empty.Visibility = if ($ui.Sites.Items.Count) { 'Collapsed' } else { 'Visible' }
}
function Save-Sites([string[]]$list) {
  [System.IO.File]::WriteAllLines($SitesFile, [string[]]($list | Sort-Object -Unique))
  Show-Sites
  # GoodbyeDPI reads the list at start, so restart it to apply changes.
  if ((Get-State) -eq 'on') { Set-Power 'restart' 'Applying changes...' } else { Show-State (Get-State) '' }
}

function ConvertTo-Domain([string]$text) {
  $t = $text.Trim().ToLower() -replace '^[a-z]+://', '' -replace '[/?#].*$', '' -replace ':\d+$', '' -replace '^\*\.', '' -replace '^www\.', ''
  if ($t -match '^[a-z0-9-]+(\.[a-z0-9-]+)+$') { $t } else { $null }
}

function Set-Message([string]$text, [string]$tone, [bool]$offerAdd = $false) {
  $ui.Message.Text = $text
  $ui.Message.Foreground = & $brush ($(switch ($tone) { 'good' { $P.Good } 'warn' { $P.Warn } default { $P.Sub } }))
  $ui.AddAnyway.Visibility = if ($offerAdd) { 'Visible' } else { 'Collapsed' }
}

# Tests whether FPT cuts the secure connection to a site (the tool never touches unlisted sites, so this sees the raw network).
$checkWork = {
  param($domain)
  $hostName = $domain
  try { [void][Net.Dns]::GetHostAddresses($hostName) } catch {
    try { $hostName = "www.$domain"; [void][Net.Dns]::GetHostAddresses($hostName) } catch { return 'nodns' }
  }
  $tcp = New-Object Net.Sockets.TcpClient
  try {
    if (-not $tcp.ConnectAsync($hostName, 443).Wait(6000)) { return 'noconnect' }
    $tcp.ReceiveTimeout = 6000; $tcp.SendTimeout = 6000
    $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, ({ $true } -as [Net.Security.RemoteCertificateValidationCallback]))
    $ssl.AuthenticateAsClient($hostName)
    'ok'
  } catch {
    $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }
    if ($e -is [Net.Sockets.SocketException] -and $e.SocketErrorCode -eq 'ConnectionReset') { 'blocked' } else { 'noconnect' }
  } finally { $tcp.Close() }
}

$script:pending = $null
function Add-Site([string]$domain, [bool]$force) {
  $list = Read-Sites
  if ($list -contains $domain) { Set-Message "$domain is already on the list." ''; return }
  Save-Sites (@($list) + $domain)
  $ui.Input.Text = ''
  $note = if ($force) { "Added $domain." } else { "$domain was blocked. Added, it should load now." }
  Set-Message $note 'good'
}

$onAdd = {
  $domain = ConvertTo-Domain $ui.Input.Text
  if (-not $domain) { Set-Message 'Type a site address, like example.com' 'warn'; return }
  if ((Read-Sites) -contains $domain) { Set-Message "$domain is already on the list." ''; return }
  # Listed sites cover their subdomains too.
  $parent = Read-Sites | Where-Object { $domain.EndsWith(".$_") } | Select-Object -First 1
  if ($parent) { Set-Message "$domain is already covered by $parent." ''; return }
  $script:pending = $domain
  $ui.Add.IsEnabled = $false
  Set-Message "Checking $domain..." ''
  Start-Work $checkWork $domain {
    param($r)
    $ui.Add.IsEnabled = $true
    $d = $script:pending
    switch ($r) {
      'blocked' { Add-Site $d $false }
      'ok' { Set-Message "$d isn't blocked by FPT, so this won't help. The problem is likely the site itself." '' $true }
      'nodns' { Set-Message "Couldn't find $d. Check the spelling." 'warn' $true }
      default { Set-Message "$d didn't respond, so it's hard to tell if FPT blocks it." 'warn' $true }
    }
  }
}
$ui.Add.Add_Click($onAdd)
$ui.AddAnyway.Add_Click({ if ($script:pending) { Add-Site $script:pending $true } })

$ui.Sites.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler]{
  param($sender, $e)
  $domain = $e.OriginalSource.Tag
  if ($domain) { Save-Sites @(Read-Sites | Where-Object { $_ -ne $domain }); Set-Message "Removed $domain." '' }
})

$ui.Input.Add_TextChanged({
  $ui.Placeholder.Visibility = if ($ui.Input.Text) { 'Collapsed' } else { 'Visible' }
  if ($ui.AddAnyway.Visibility -eq 'Visible') { Set-Message '' '' }
})
$ui.Input.Add_GotKeyboardFocus({ $ui.FieldBorder.BorderBrush = & $brush $P.Accent })
$ui.Input.Add_LostKeyboardFocus({ $ui.FieldBorder.BorderBrush = & $brush $P.Stroke })

# Pick up changes made outside the app (e.g. turned off elsewhere) when the window regains focus.
$win.Add_Activated({ if (-not $script:jobs.Count) { Show-State (Get-State) '' } })

Show-Sites
Show-State (Get-State) ''
$ui.Startup.IsChecked = Get-Startup
$win.Add_ContentRendered({ $ui.Input.Focus() })

# Keep running with the window hidden; only Quit in the tray menu ends the app.
$app = New-Object Windows.Application
$app.ShutdownMode = 'OnExplicitShutdown'
if (-not $Tray) { $win.Show() }
[void]$app.Run()
$mutex.ReleaseMutex()
