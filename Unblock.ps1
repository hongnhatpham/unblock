# Unblock: a small window to switch GoodbyeDPI on/off and edit which sites it unblocks.
# Launch with Unblock.vbs (no console flash). Needs install.ps1 to have run once (the app offers it).
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$Root = $PSScriptRoot
$SitesFile = Join-Path $Root 'sites.txt'
$IconFile = Join-Path $Root 'unblock.ico'
$Service = 'GoodbyeDPI'

# One window at a time.
$mutex = New-Object System.Threading.Mutex($false, 'Local\HongUnblockApp')
if (-not $mutex.WaitOne(0)) { exit }

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

    <Border Grid.Row="0" Background="$($P.Card)" BorderBrush="$($P.Stroke)" BorderThickness="1" CornerRadius="8" Padding="18,16">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel VerticalAlignment="Center">
          <TextBlock x:Name="StateTitle" Text="Off" FontSize="20" FontWeight="SemiBold" FontFamily="Segoe UI Variable Display, Segoe UI"/>
          <TextBlock x:Name="StateSub" Text="" Foreground="$($P.Sub)" Margin="0,2,0,0" TextWrapping="Wrap"/>
        </StackPanel>
        <ToggleButton x:Name="Power" Grid.Column="1" Style="{StaticResource Switch}" VerticalAlignment="Center" Margin="16,0,0,0"/>
      </Grid>
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
foreach ($n in 'StateTitle', 'StateSub', 'Power', 'Sites', 'Empty', 'Input', 'Placeholder', 'FieldBorder', 'Add', 'Message', 'AddAnyway') { $ui[$n] = $win.FindName($n) }
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
})
$timer.Start()

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
$win.Add_ContentRendered({ $ui.Input.Focus() })
[void]$win.ShowDialog()
$mutex.ReleaseMutex()
