# Unblock

A small Windows app that gets around ISP site blocking (built for FPT in Vietnam blocking Canvas, `rmit.instructure.com`).

FPT cuts secure connections to some sites by reading the site name at the start of the connection. Unblock runs [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI) in the background to split that first message so the filter can't read it. Only sites on your list are touched; everything else goes through as normal.

## Setup

Right-click `install.ps1` and choose **Run with PowerShell**, then approve the admin prompt. It:

- downloads GoodbyeDPI 0.2.3rc3 and checks its SHA-256 fingerprint
- installs it as a background service that starts with Windows
- lets your account switch it on and off without admin
- adds **Unblock** to the Desktop and Start menu, and starts it in the tray when you sign in

Run it again any time; it's safe to repeat. If you move this folder, run it again so the service points at the new place.

## Using it

- **Switch**: turns unblocking on or off.
- **Start with Windows**: when on, Unblock opens quietly in the tray at sign-in and unblocking starts by itself. When off, neither starts until you open the app.
- **Tray**: closing or minimizing the window sends it to the tray (Windows may tuck the icon under the ^ arrow; drag it onto the taskbar to keep it visible). The icon is coloured when on and grey when off. Click it to open the window, right-click to turn unblocking on/off or quit. Unblocking keeps working even after you quit.
- **Add a site**: type an address like `example.com`. Unblock first tests whether FPT really blocks it. If it does, it's added and starts working. If the site loads fine on its own, Unblock says so and offers *Add anyway*.
- **✕**: removes a site. A site covers its subdomains, so `instructure.com` covers `rmit.instructure.com`.

Your list lives in `sites.txt` (not tracked in git). A new setup starts from `sites.default.txt`.

## Limits

- Fixes this PC only. Phones and other devices on the same Wi-Fi are still blocked.
- Uses GoodbyeDPI's gentle mode (`-e 2 --native-frag`). The aggressive `-9` mode broke many Cloudflare sites on FPT.

## Removing

Right-click `uninstall.ps1` and choose **Run with PowerShell**. It removes the service, shortcuts and sign-in entry, and leaves this folder.
