# Unblock

A small Windows app that gets around ISP site blocking (built for FPT in Vietnam blocking Canvas, `rmit.instructure.com`).

FPT cuts connections to some sites by reading the site name at the start of the connection. Unblock is a small front end for [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI): it runs the original GoodbyeDPI in the background to split and disguise that first message so the filter can't read it, and lets you pick its options.

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
- **Unblock: All sites / My list**: *All sites* works like plain GoodbyeDPI and covers everything, including apps like Steam that use many addresses. *My list* only touches the sites you add (GoodbyeDPI's `--blacklist`).
- **GoodbyeDPI options**: the exact options GoodbyeDPI runs with. Pick a preset or type your own (*All options* opens GoodbyeDPI's list), then press Enter or **Apply**. Esc undoes your typing.
  - *Recommended* (`-f 2 -e 2 --native-frag --reverse-frag --auto-ttl`): tested on FPT. Works for Steam's store, community, downloads and cloud, and keeps Cloudflare sites working.
  - *GoodbyeDPI default* (`-9`): on FPT it breaks many Cloudflare sites (Discord, LinkedIn, X) when used for all sites, so pair it with *My list*.
  - *Gentle* (`-e 2 --native-frag`): Unblock's old setting. Only splits secure connections, so Steam downloads stay blocked.
- **Add a site** (My list): type an address like `example.com`. Unblock first tests whether FPT really blocks it. If it does, it's added and starts working. If the site loads fine on its own, Unblock says so and offers *Add anyway*.
- **✕**: removes a site. A site covers its subdomains, so `instructure.com` covers `rmit.instructure.com`.

Your list lives in `sites.txt` (not tracked in git). A new setup starts from `sites.default.txt`. The options live only in the GoodbyeDPI service itself, so the app always shows what's really running, and running `install.ps1` again keeps them.

## Limits

- Fixes this PC only. Phones and other devices on the same Wi-Fi are still blocked.
- FPT changes its filter now and then. If something stops loading, try the other presets.

## Removing

Right-click `uninstall.ps1` and choose **Run with PowerShell**. It removes the service, shortcuts and sign-in entry, and leaves this folder.
