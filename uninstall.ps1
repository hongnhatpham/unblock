# Removes the GoodbyeDPI service and the Unblock shortcuts. Leaves this folder in place. Asks for admin permission.
param([string]$UserSid)
if (-not $UserSid) { $UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -UserSid $UserSid"
  exit
}
sc.exe stop GoodbyeDPI 2>&1 | Out-Null
sc.exe delete GoodbyeDPI 2>&1 | Out-Null
sc.exe stop WinDivert 2>&1 | Out-Null
$profileDir = (Get-CimInstance Win32_UserProfile | Where-Object SID -eq $UserSid).LocalPath
Remove-Item "$profileDir\Desktop\Unblock.lnk", "$profileDir\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Unblock.lnk" -ErrorAction SilentlyContinue
