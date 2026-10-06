# NixOS on a Lenovo 14e Chromebook

This repo turns a 2019 **Lenovo 14e Chromebook** (board name **LIARA**) into a
simple, lightweight laptop for web browsing, email, and terminal work.

It replaces ChromeOS with [NixOS](https://nixos.org) 26.05. The whole system is
described by the files in this repo, so you can rebuild it, roll it back, or
change it by editing text files.

**What you get**

- Auto-login straight into a light desktop ([labwc](https://labwc.github.io/))
  with a ChromeOS-style panel at the bottom
- Firefox (with uBlock Origin), Thunderbird, a file manager (Thunar), and a
  terminal (foot)
- Wi-Fi, Bluetooth, sound, brightness, and suspend on lid close
- Chromebook keyboard keys that work like they do on ChromeOS
- [Tailscale](https://tailscale.com) for reaching the laptop from your other devices
- Easy updates (`sysupdate`), cleanup (`sysclean`), and rollback (`sysrollback`)

> **This erases ChromeOS and everything on the laptop.** It also replaces the
> laptop's firmware. Read each step before you do it. Warnings are marked ⚠️.

---

## Contents

1. [What you need](#1-what-you-need)
2. [Before you start](#2-before-you-start)
3. [Enable Developer Mode](#3-enable-developer-mode)
4. [Disable write protection](#4-disable-write-protection)
5. [Flash the UEFI Full ROM firmware](#5-flash-the-uefi-full-rom-firmware)
6. [Make the NixOS installer USB](#6-make-the-nixos-installer-usb)
7. [Boot the installer and install](#7-boot-the-installer-and-install)
8. [First boot](#8-first-boot)
9. [Daily use](#9-daily-use)
10. [Updating from your main computer over Tailscale](#10-updating-from-your-main-computer-over-tailscale)
11. [Upgrading to NixOS 26.11](#11-upgrading-to-nixos-2611)

Also: [Post-install checklist](docs/post-install-checklist.md) ·
[Troubleshooting](docs/troubleshooting.md) ·
[Repo layout](#repo-layout) · [Sources](#sources)

---

## 1. What you need

- **Two USB sticks**
  - **Stick #1** (any size, normal FAT32 format): for the backup of the
    laptop's original firmware. Keep this backup forever.
  - **Stick #2** (at least 2 GB): for the NixOS installer. It will be erased.
- **The charger.** It must be a USB-C charger of at least 45 W (the original
  Lenovo charger is fine). The laptop runs from it while the battery is
  unplugged.
- **A small Phillips screwdriver** to open the bottom cover.
- **Your main computer** (Linux) to download and write the installer.
- **Wi-Fi** with internet access.
- **About two hours.**

## 2. Before you start

1. **Back up your files.** Copy anything you want to keep from the
   Chromebook's Downloads folder to Google Drive or a USB stick. Everything on
   the laptop will be erased.
2. **Confirm the board name is LIARA.**
   1. Turn the laptop off.
   2. Hold **Esc** and **Refresh** (the circular-arrow key, 4th key on the top
      row), then press **Power**. Let go when the Recovery screen appears.
   3. At the bottom of the screen there is a hardware ID (HWID). Its first
      word should be **LIARA**, for example `LIARA A1B-C2D-...`.
   4. If it is not LIARA, **stop here**: these instructions are only for LIARA.

   Stay on this screen and continue with step 3.

## 3. Enable Developer Mode

Developer Mode lets you run the firmware tool in step 5.

> ⚠️ This erases all data on the Chromebook (a "powerwash").
>
> ⚠️ The **battery must still be connected** for this step. Don't open the
> laptop yet.

1. On the Recovery screen (from step 2), press **Ctrl+D**.
2. Press **Enter** to confirm turning OS verification off. The laptop restarts.
3. On the "OS verification is OFF" screen, press **Ctrl+D** (or wait). The
   first time, the laptop spends a few minutes preparing Developer Mode.
4. When ChromeOS starts, you don't need to log in or set it up. Turn the laptop
   off (hold Power and choose **Power off**, or hold Power for 10 seconds).

From now on, each start shows the "OS verification is OFF" screen. Press
**Ctrl+D** to continue to ChromeOS.

Source: [MrChromebox: Developer Mode](https://docs.mrchromebox.tech/docs/boot-modes/developer.html)

## 4. Disable write protection

The firmware chip is write-protected. On LIARA (which has a CR50 security
chip) you turn this off by **disconnecting the battery** and running the
laptop from the charger. MrChromebox's
[Supported Devices](https://docs.mrchromebox.tech/docs/supported-devices.html)
table lists LIARA with the write-protect method "CR50 (SuzyQ, battery)".

> ⚠️ Work on a table, unplug the charger first, and touch something metal to
> discharge static before touching the inside of the laptop.

1. Make sure the laptop is **off** and the **charger is unplugged**.
2. Turn the laptop over and remove the screws on the bottom cover.
3. Carefully pry the bottom cover off, starting at a corner (a plastic card or
   guitar pick works well).
4. Find where the battery cable plugs into the motherboard. Pull the connector
   **straight out of its socket** (pull the plastic connector, not the wires).
5. Put the bottom cover back on loosely (one or two screws are enough for now).
6. Plug in the charger. The laptop may start by itself. If not, press Power.
7. On the "OS verification is OFF" screen, press **Ctrl+D**.

The laptop now runs from the charger only. **Don't unplug the charger** until
step 5 tells you to.

Source: [MrChromebox: Disabling Write Protect](https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html)

## 5. Flash the UEFI Full ROM firmware

The "UEFI Full ROM" firmware from MrChromebox replaces the ChromeOS firmware
so the laptop can boot normal operating systems. It is the only practical
option on this laptop: the other option (Legacy Boot Mode) doesn't work on most
Stoney Ridge Chromebooks
([Known Issues](https://docs.mrchromebox.tech/docs/known-issues.html)).

> ⚠️ Don't let the laptop lose power while flashing. Keep the charger plugged in.

1. On the ChromeOS welcome screen, connect to **Wi-Fi** (the script downloads
   the firmware). Don't sign in to a Google account.
2. Press **Ctrl+Alt+→**. The → key is the **Forward** key on the top row (it
   acts as F2 here). A text console appears.
3. Type `chronos` and press **Enter** (no password). (**Ctrl+Alt+←** goes back
   to the welcome screen if you need it.)
4. Run this command, copied from
   [MrChromebox's Firmware Utility Script page](https://docs.mrchromebox.tech/docs/fwscript.html).
   Note it is `-LOf` (capital letter O), not zero:

   ```
   cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
   ```

5. The script shows a menu. At the top, check that it shows **LIARA** and that
   firmware write protect is **disabled**. If write protect is still enabled,
   the battery is still connected; go back to step 4 of section 4.
6. Type **2** and press Enter (**Install/Update UEFI (Full ROM) Firmware**).
   Answer the questions exactly like this (any other answer cancels and
   returns to the menu):
   1. "Do you wish to continue? [y/N]": type **y**, Enter.
   2. A notice about a USB-C debug cable and "Type I ACCEPT": type
      **I ACCEPT** (capital letters, one space), Enter. You don't need the
      cable.
   3. A note that ChromeOS will no longer boot, "Press Y to continue": type
      **Y**, Enter.
7. When it asks **"Create backup now? [Y/n]"**, press **Y** and Enter, insert
   **USB stick #1**, and pick it from the list. When it says the backup is
   complete, remove the stick and press **Enter**. Keep this stick: the file
   on it (`stock-firmware-LIARA-<date>.rom`) is the only way to put the
   ChromeOS firmware back exactly as it was.
8. Wait for the script to download and flash the firmware. When it says it
   finished, press **Enter** to return to the menu.
9. Type **P** and press Enter to **power off**.
10. Unplug the charger. Open the bottom cover again, **reconnect the battery**
    (push the connector straight into its socket), and screw the cover back on
    fully.
11. Plug in the charger to wake the laptop. Press Power if it doesn't start.

> **A black screen for 20–60 seconds on the first start is normal.** The new
> firmware is training the memory. Don't turn the laptop off. It can take up to
> 2 minutes. Later starts are fast.

After that you see a rabbit logo (the new firmware's start screen). With no
operating system installed yet, it then shows the boot menu or a `Shell>`
prompt. That is fine. Turn the laptop off (hold Power) and continue.

**Copy the firmware backup** from USB stick #1 to your main computer as well.

## 6. Make the NixOS installer USB

Do this on your main computer.

1. Download the NixOS 26.05 **minimal** installer and its checksum:

   ```
   curl -LO https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
   curl -LO https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso.sha256
   ```

   (These are the files linked from <https://nixos.org/download/> under
   "Minimal ISO image, 64-bit Intel/AMD".)

2. Check the download isn't damaged. This should print `... OK`:

   ```
   echo "$(cut -d' ' -f1 latest-nixos-minimal-x86_64-linux.iso.sha256)  latest-nixos-minimal-x86_64-linux.iso" | sha256sum -c
   ```

3. Find USB stick #2's device name. Run this, plug the stick in, and run it
   again. The new line is the stick, for example `sdb` with `TRAN` = `usb`:

   ```
   lsblk -o NAME,SIZE,MODEL,TRAN,RM
   ```

4. Write the installer to the stick. Replace `/dev/sdX` with the stick's name
   from step 3 (for example `/dev/sdb`; the whole device, not `sdb1`).

   > ⚠️ `dd` overwrites whatever you name, without asking. If you name your
   > main computer's disk, you erase it. Check the name and size twice.

   ```
   sudo umount /dev/sdX* 2>/dev/null; sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

   If you prefer a graphical tool, GNOME Disks ("Restore Disk Image…") or
   [Impression](https://flathub.org/apps/io.gitlab.adhami3310.Impression) also
   work.

## 7. Boot the installer and install

1. Plug USB stick #2 into the Chromebook and the charger into the wall.
2. Press Power. When the rabbit logo appears, press **Esc**.
3. Choose **Boot Menu**, then the USB stick. (If it isn't listed, go back,
   unplug and replug the stick, wait 3 seconds, and open the Boot Menu again.)
   Source: [MrChromebox: Booting Your OS](https://docs.mrchromebox.tech/docs/firmware/booting.html)
4. Pick the first entry in the NixOS menu. After a minute you get a text prompt,
   already logged in as the user `nixos`.
5. **Connect to Wi-Fi.** Run `nmtui`, choose **Activate a connection**, pick
   your network, and type the password. Choose **Back**, then **Quit**. Check
   it works:

   ```
   ping -c 3 nixos.org
   ```

6. **Get this repo:**

   ```
   git clone https://github.com/derikatwork/blackbook
   ```

7. **Find the internal disk.** It is an eMMC, usually `mmcblk0`, with no
   `TRAN` value (or `mmc`) and `RM` = `0`. The USB stick shows `TRAN` = `usb`.

   ```
   lsblk -o NAME,SIZE,MODEL,TRAN,RM
   ```

   Ignore entries like `mmcblk0boot0`, `mmcblk0boot1`, and `mmcblk0rpmb`.
   Those are small hidden areas of the same chip, not the disk.

8. **Install.** Replace `/dev/mmcblk0` if step 7 showed a different name:

   > ⚠️ This erases the disk you name, including ChromeOS. The script shows
   > the disks, refuses USB and removable drives, and asks you to type the
   > disk name again before it changes anything.

   ```
   sudo bash blackbook/scripts/install.sh /dev/mmcblk0
   ```

   The script explains each step as it goes:

   - It partitions and formats the disk, then copies this repo to
     `/home/derik/nixos-config`.
   - It checks that the repo lists every kernel module the hardware needs. If
     something is missing, it **stops** and tells you exactly which line to add
     to `blackbook/hosts/liara/hardware-configuration.nix`. Add it with
     `nano` and run the same command again.
   - It installs NixOS (about 2 GB of downloads).
   - It asks you to **choose your password** (twice). You need it for `sudo`
     and to unlock the screen.

9. When it says **NixOS is installed**, type `reboot` and remove the USB stick
   when the screen goes dark.

## 8. First boot

1. The boot menu shows for 2 seconds, then the desktop starts by itself. You
   aren't asked for a password at startup.
2. Connect to Wi-Fi: click the Wi-Fi icon at the bottom right of the panel
   and pick your network. The password is saved for next time.
3. Open a terminal (**Ctrl+Alt+T**) and connect Tailscale:

   ```
   sudo tailscale up
   ```

   It prints a link. Open it on your phone or main computer and log in to add
   the laptop to your tailnet. It appears there as **liara**. Check with:

   ```
   tailscale status
   ```

4. Go through the [post-install checklist](docs/post-install-checklist.md).
   It tests every key, sound, the lid, Bluetooth, and more.

## 9. Daily use

### Keyboard shortcuts

The **Search** key (🔍, where Caps Lock usually is) works like the Windows/Super
key.

| Keys | What it does |
|---|---|
| Tap **Search** (on its own) | Open the app launcher (type to search, Enter to start) |
| **Search+Space** or the **Overview** key | Open the app launcher |
| **Search+Enter** or **Ctrl+Alt+T** | Terminal |
| **Search+B** | Firefox |
| **Search+M** | Thunderbird (email) |
| **Search+E** | Files |
| **Search+L** | Lock the screen |
| **Alt+Tab** / **Alt+Shift+Tab** | Switch windows |
| **Alt+[** / **Alt+]** | Snap window to the left / right half |
| **Alt+=** | Maximize / restore window |
| **Search+Q** or **Alt+Fullscreen** (= Alt+F4) | Close window |
| **Fullscreen** key | Make the window fullscreen (press again to leave) |
| **Back**, **Forward**, **Refresh** keys | Back, forward, reload (in Firefox) |
| **Brightness** keys | Screen brightness |
| **Mute**, **Volume** keys | Sound (volume stops at 100%) |
| **Search + a top-row key** | F1–F10 (Back = F1 … Volume up = F10) |
| **Search+Backspace** | Delete |
| **Search+←** / **Search+→** | Home / End |
| **Search+↑** / **Search+↓** | Page Up / Page Down |
| **Search+Shift+S** | Screenshot of an area (drag to select, Esc cancels) |
| **Ctrl+Overview** | Screenshot of the whole screen |
| **Power** key | Suspend (sleep) |
| **Ctrl+Alt+Forward** | Text console, for emergencies (**Ctrl+Alt+Back** returns to the desktop) |

Screenshots are saved in `~/Pictures/Screenshots` and copied to the clipboard.

**Right-click the desktop background** for a menu with Terminal, Firefox,
Thunderbird, Files, Wi-Fi, Bluetooth, Sound, Lock, Log out, Reboot, and Shut
down. The **⏻** button at the bottom right does Lock, Suspend, Log out, Reboot,
and Shut down. Closing the lid suspends; opening it shows the lock screen.

### The panel

From left to right: **◉** opens the launcher, then your open windows (click to
switch, middle-click to close). On the right: tray icons (Wi-Fi, Bluetooth),
Bluetooth status, network, volume (scroll to change, click for sound
settings), brightness (scroll to change), battery, and the clock (hover for a
calendar).

### Wi-Fi and Bluetooth

- **Wi-Fi:** click the Wi-Fi tray icon and pick a network. Passwords are saved
  for the whole system, so the laptop reconnects after a restart. (In the
  password box, leave the little icon on "Store the password for all users".)
- **Bluetooth:** click the Bluetooth tray icon (or right-click the desktop →
  Bluetooth), choose **Search**, then pair your device.

### Updating: `sysupdate`

The configuration lives in `~/nixos-config` (a copy of this GitHub repo). To
change the system, change the files in this repo on GitHub (or on your main
computer and push), then on the Chromebook run:

```
sysupdate
```

It downloads the newest version of the repo (`git pull`) and switches to it.
It asks for your password.

To get **newer software** (security fixes), update `flake.lock`: on your main
computer run `nix flake update` in the repo, commit, push, then run `sysupdate`
on the Chromebook. Or, on the Chromebook:

```
cd ~/nixos-config && nix flake update && nixos-rebuild switch --sudo --flake .#liara
```

(Then push the new `flake.lock` to GitHub, or the next `git pull` will
complain. If it does, run `git -C ~/nixos-config checkout flake.lock` and try
again.)

If you edit files directly in `~/nixos-config`, run
`nixos-rebuild switch --sudo --flake ~/nixos-config#liara` to apply them.
New files must be added to git first (`git add`), or Nix won't see them.

### Cleaning up: `sysclean`

```
sysclean
```

Deletes old system versions and frees their disk space, then refreshes the
boot menu. Old versions older than 14 days are also cleaned up automatically
every week. Use `df -h /` to see free space.

### Undoing a bad update

Every update keeps the previous version ("generation"). To go back:

- **If the desktop still works:** run `sysrollback`.
- **If the laptop doesn't start properly:** restart it, and while the boot menu
  shows (2 seconds), press **↓** to stop the countdown. Pick an older entry and
  press Enter. Once you're back, run `sysrollback` to make that version the
  default again. The menu keeps the 3 newest versions.

### Display size

The screen starts at scale 1.0. To try bigger text and icons (1.25) for this
session only:

```
nix shell nixpkgs#wlr-randr -c wlr-randr --output eDP-1 --scale 1.25
```

(Run `nix shell nixpkgs#wlr-randr -c wlr-randr` first if `eDP-1` isn't the
screen's name.) It resets when you log out. To keep it, add `pkgs.wlr-randr`
to `environment.systemPackages` in `modules/desktop.nix`, add the line
`wlr-randr --output eDP-1 --scale 1.25` near the top of
`files/labwc/autostart`, and run `sysupdate`.

### YouTube and video

This laptop's graphics chip can decode H.264 video in hardware, but not VP9 or
AV1, which YouTube prefers. Those play in software and may stutter. An
extension that makes YouTube send H.264 instead, such as **enhanced-h264ify**
(from addons.mozilla.org), helps a lot. It isn't installed by default; add it
in Firefox if you want it.

## 10. Updating from your main computer over Tailscale

SSH is **off** right now, because no SSH key is set. With SSH on, your main
computer can build the system (much faster than the Chromebook) and copy it
over Tailscale.

**To turn SSH on:**

1. On your main computer, show your public key (create one with
   `ssh-keygen -t ed25519` if you have none):

   ```
   cat ~/.ssh/id_ed25519.pub
   ```

2. In `hosts/liara/configuration.nix`, put it in the `sshKeys` list (only the
   `.pub` key, never the private one):

   ```nix
   sshKeys = [ "ssh-ed25519 AAAA... you@main-computer" ];
   ```

3. Push the change and run `sysupdate` on the Chromebook.

SSH then accepts only that key, only over Tailscale (`tailscale0`), and never
for root.

**To update from your main computer** (it needs Nix with flakes, and must be
on your tailnet):

```
cd blackbook   # your clone of this repo
nix run github:NixOS/nixpkgs/nixos-26.05#nixos-rebuild -- switch --flake .#liara --target-host derik@liara --sudo --ask-sudo-password
```

It builds the system on your main computer, copies it to the Chromebook, and
switches to it. It asks for the Chromebook password (for `sudo`). Push your
changes to GitHub too, so the Chromebook's `sysupdate` stays in step.

## 11. Upgrading to NixOS 26.11

NixOS 26.05 gets updates until **2026-12-31**. Before then, move to 26.11:

1. Run `sysclean` first, and plug in the charger.
2. In `flake.nix`, change `nixos-26.05` to `nixos-26.11` (one line):

   ```nix
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.11";
   ```

3. Update the lock file and switch (on the Chromebook):

   ```
   cd ~/nixos-config
   nix flake update
   nixos-rebuild boot --sudo --flake .#liara
   ```

   If this stops with an error about an option, read the 26.11 release notes
   (in the [NixOS manual](https://nixos.org/manual/nixos/stable/release-notes))
   for renamed settings.

4. Reboot. If something is wrong, pick the previous entry in the boot menu.
5. Commit and push `flake.nix` and `flake.lock`.

Don't change `system.stateVersion` in `configuration.nix`. It stays at
`"26.05"`.

---

## Repo layout

```
flake.nix, flake.lock         Which NixOS version (26.05) and the system "liara"
hosts/liara/
  configuration.nix           User name, hostname, SSH keys; imports the modules
  hardware-configuration.nix  Disks (by label) and kernel modules
modules/
  base.nix                    Nix settings, cleanup, memory, language, user, shell, tools
  boot.nix                    Boot menu and kernel
  hardware.nix                Firmware, graphics, keyboard (keyd), power, Bluetooth, lid
  audio.nix                   Sound (PipeWire)
  network.nix                 Wi-Fi, Tailscale, firewall, SSH
  desktop.nix                 labwc, login, look, fonts, apps, config files
files/                        Config files for labwc, Waybar, fuzzel, foot, mako,
                              swaylock, nano, keyd, GTK, and small helper scripts
scripts/install.sh            Run from the NixOS installer (section 7)
docs/                         Post-install checklist and troubleshooting
```

Config files in `files/` are installed to `/etc/xdg/...`. To change one just
for yourself, copy it to the same place under `~/.config/` and edit it there;
your copy wins. To change it for the system, edit it in this repo and run
`sysupdate`.

### Why some things are set up the way they are

- **Kernel:** speaker and microphone support for Stoney Ridge arrived in Linux
  6.19, and NixOS 26.05 defaults to 6.18. So this uses the newest kernel
  (`linuxPackages_latest`, 7.2.9 when this was written). Like everything else,
  it comes ready-built from cache.nixos.org; nothing big is compiled on the
  laptop.
- **1 GiB boot partition, 3 boot entries:** each entry stores a kernel on the
  boot partition. Too small a partition has broken installs on other Stoney
  Ridge Chromebooks.
- **No disk encryption tied to the security chip:** the Chromebook's chip
  isn't a full TPM 2.0 ([Known Issues](https://docs.mrchromebox.tech/docs/known-issues.html)).
- **Swap:** compressed swap in RAM (zram, half of the 4 GB), with
  `vm.swappiness = 180` because zram is much faster than disk swap.
  earlyoom closes the biggest program (and tells you) before memory runs out
  completely.
- **Keyboard:** [keyd](https://github.com/rvaiya/keyd), with a map based on
  [cros-keyboard-map](https://github.com/WeirdTreeThing/cros-keyboard-map).
- **Audio:** the two WirePlumber settings from
  [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
  are built in (`modules/audio.nix`). That script itself isn't used; it
  doesn't support NixOS.
- **Not running:** ModemManager (no cellular modem) and the speech service.

## Sources

- MrChromebox: [Supported Devices](https://docs.mrchromebox.tech/docs/supported-devices.html),
  [Firmware Utility Script](https://docs.mrchromebox.tech/docs/fwscript.html),
  [Disabling Write Protect](https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html),
  [Booting Your OS](https://docs.mrchromebox.tech/docs/firmware/booting.html),
  [Known Issues](https://docs.mrchromebox.tech/docs/known-issues.html),
  [Developer Mode](https://docs.mrchromebox.tech/docs/boot-modes/developer.html),
  [Recovery Mode](https://docs.mrchromebox.tech/docs/boot-modes/recovery.html),
  [Restoring Stock Firmware](https://docs.mrchromebox.tech/docs/reverting/flashing-stock.html)
- chrultrabook: [Known Issues](https://docs.chrultrabook.com/docs/installing/known-issues.html)
  ("Stoney Ridge audio requires Linux kernel 6.19 or newer")
- [NixOS manual: Installation](https://nixos.org/manual/nixos/stable/#ch-installation)
- [labwc documentation](https://labwc.github.io/)
- [keyd](https://github.com/rvaiya/keyd),
  [cros-keyboard-map](https://github.com/WeirdTreeThing/cros-keyboard-map)
