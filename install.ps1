# Sets up Unblock: downloads GoodbyeDPI, installs it as a background service for the sites in sites.txt,
# lets the current user switch it on/off without admin, and adds Desktop and Start menu shortcuts.
# Safe to run again. Asks for admin permission once.
param([string]$UserSid)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

if (-not $UserSid) { $UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  # Pass the real user's ID through, so the switch permission goes to them and not the admin account.
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -UserSid $UserSid"
  exit
}

# GoodbyeDPI release, pinned and checked against its known fingerprint.
$Version = '0.2.3rc3-2'
$Url = "https://github.com/ValdikSS/GoodbyeDPI/releases/download/0.2.3rc3/goodbyedpi-$Version.zip"
$Sha256 = '37F96B32D050DADCC930A639EBA68E1CCD57ED5C04A5F77DFCA908F01905A4C5'
$Exe = Join-Path $Root "goodbyedpi-$Version\x86_64\goodbyedpi.exe"
$Sites = Join-Path $Root 'sites.txt'

try {
  if (-not (Test-Path $Exe)) {
    $zip = Join-Path $env:TEMP "goodbyedpi-$Version.zip"
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    Invoke-WebRequest $Url -OutFile $zip -UseBasicParsing
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $Sha256) { Remove-Item $zip; throw 'GoodbyeDPI download did not match its expected fingerprint.' }
    Expand-Archive $zip -DestinationPath $Root -Force
    Remove-Item $zip
  }
  if (-not (Test-Path $Sites)) { Copy-Item (Join-Path $Root 'sites.default.txt') $Sites }

  # Gentle mode: only split the HTTPS handshake, only for listed sites. The aggressive -9 mode broke Cloudflare sites.
  sc.exe stop GoodbyeDPI 2>&1 | Out-Null
  sc.exe delete GoodbyeDPI 2>&1 | Out-Null
  # Unload GoodbyeDPI's network driver too, so it reloads from this folder if the folder moved.
  sc.exe stop WinDivert 2>&1 | Out-Null
  for ($i = 0; $i -lt 25 -and (Get-Service GoodbyeDPI -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 200 }
  # New-Service, not sc.exe: Windows PowerShell drops the quotes sc.exe needs around paths with spaces.
  New-Service GoodbyeDPI -BinaryPathName "`"$Exe`" -e 2 --native-frag --blacklist `"$Sites`"" -StartupType Automatic `
    -DisplayName 'GoodbyeDPI' -Description 'Gets around ISP site blocking for the sites in Unblock' | Out-Null
  # Default service permissions, plus start/stop for the user.
  sc.exe sdset GoodbyeDPI "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;CCLCSWRPWPDTLOCRRC;;;$UserSid)" | Out-Null
  sc.exe start GoodbyeDPI | Out-Null

  # Shortcuts go in the real user's folders, found from their ID.
  $profileDir = (Get-CimInstance Win32_UserProfile | Where-Object SID -eq $UserSid).LocalPath
  $shell = New-Object -ComObject WScript.Shell
  foreach ($dir in "$profileDir\Desktop", "$profileDir\AppData\Roaming\Microsoft\Windows\Start Menu\Programs") {
    if (-not (Test-Path $dir)) { continue }
    $lnk = $shell.CreateShortcut("$dir\Unblock.lnk")
    $lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $lnk.Arguments = "`"$Root\Unblock.vbs`""
    $lnk.WorkingDirectory = $Root
    $lnk.IconLocation = "$Root\unblock.ico"
    $lnk.Description = 'Switch site unblocking on or off'
    $lnk.Save()
  }
} catch {
  Add-Type -AssemblyName PresentationFramework
  [void][Windows.MessageBox]::Show("Unblock setup failed: $($_.Exception.Message)", 'Unblock')
  exit 1
}
