# CLAUDE.md: NixOS for a Lenovo 14e Chromebook (board LIARA)

## What you're building

A Git repo (a NixOS flake) that turns a 2019 Lenovo 14e Chromebook into a simple, lightweight laptop for web browsing, email, and terminal work.

You (Claude Code) run on the user's main computer, not on the Chromebook. You write and validate the configuration. The user flashes the firmware and installs NixOS by hand, following the README you write.

The user is comfortable with technology but is not a NixOS expert. Everything they do by hand must be in the README as exact, copy-pasteable steps, with plain-language explanations and clear warnings before anything destructive.

## Hard rules

1. **Never touch disks or firmware on this machine.** Only write files and run read-only, evaluation, or build commands (`nix eval`, `nix build`, `nix flake check`, `git`, `shellcheck`). Partitioning, formatting, and installing happen on the Chromebook, by the user.
2. **Pin nixpkgs to `nixos-26.05`.** Its support ends 2026-12-31. The README must explain how to move to `nixos-26.11` (one line in `flake.nix`).
3. **Everything must come from the official binary cache (cache.nixos.org).** The Chromebook has a slow dual-core CPU and 4 GB of RAM. Compiling a kernel, Firefox, or mesa on it is not acceptable. Avoid overlays or overrides that change the hash of large packages. Prove this with the dry run in Phase 3.
4. **Verify every NixOS option against 26.05** (search.nixos.org/options with the 26.05 channel, or `nix eval`). Don't write option names from memory. Several were renamed in recent releases, such as the logind settings and the `nixos-rebuild` sudo flag.
5. **Copy firmware commands from the official MrChromebox docs** at build time and link the source page in the README. Don't write firmware commands from memory.
6. **No secrets in the repo.** That means no password hashes, Wi-Fi passwords, Tailscale auth keys, or private keys. SSH *public* keys are fine.
7. **Keep it small.** No Home Manager, Flatpak, Qt apps, CJK font packages, or extra desktop environments. Don't add anything not in this file without asking the user.
8. **Don't run or vendor WeirdTreeThing's `chromebook-linux-audio` script.** It assumes a mutable distro and won't work on NixOS. If you need what it does, read it and reproduce the relevant parts declaratively.

## Hardware facts

| | |
|---|---|
| Device | Lenovo 14e Chromebook (2019, model 81MH) |
| Board | LIARA (grunt family). The user should confirm this from the Recovery screen. |
| CPU/GPU | AMD A4-9120C (Stoney Ridge), Radeon R4 (amdgpu driver) |
| RAM | 4 GB, soldered |
| Storage | eMMC. Lenovo lists 32 GB as the smallest option; the user reported 16 GB, which is probably ChromeOS free space. Budget so the system fits comfortably in 16 GB. The device is probably `/dev/mmcblk0`, but always confirm with `lsblk`. |
| Display | 14" 1920×1080 (some units are touchscreens) |
| Wireless | Wi-Fi 5, Bluetooth 4.2 |
| Firmware | Target is MrChromebox **UEFI Full ROM**. Legacy Boot Mode is broken on most Stoney Ridge devices, so Full ROM is the only practical path. |
| Write protect | Early CR50 device. Check LIARA's row in MrChromebox's Supported Devices table for the method (usually battery disconnect). |

Known quirks to design around:

- **Audio.** The Stoney Ridge speaker and mic fixes landed in mainline Linux 6.19. NixOS 26.05 defaults to 6.18, so use `pkgs.linuxPackages_latest`, which is in the binary cache. Confirm the evaluated kernel version is 6.19 or newer; if it isn't, stop and tell the user.
- **EFI partition size.** systemd-boot keeps a copy of every kernel and initrd on the EFI partition. A too-small partition has broken installs of other distros on Stoney Chromebooks. Use a 1 GiB EFI partition and keep only 3 boot entries.
- **No full TPM.** The Google security chip isn't a full TPM 2.0. Don't use TPM-bound disk encryption.
- **First boot after flashing** shows a black screen for 20–60 seconds while the firmware trains the RAM. The README must say this is normal.
- **Keyboard.** There is no key labeled Super; the Search key sends Super (Left Meta). Top-row key behavior must be confirmed on the device.

## Phase 0: ask before writing anything

Ask the user these in one message:

- Username and full name.
- Hostname. Default is `liara`; it is also the flake output name and the Tailscale device name.
- GitHub repo name. Public is easiest to clone from the installer, and nothing secret will be in it.
- An SSH public key from the main computer, for SSH that only works over Tailscale. This is optional; with no key, leave SSH disabled.
- Defaults you'll use unless told otherwise: timezone America/Los_Angeles, locale en_US.UTF-8, US keyboard, light GTK theme.

Then check this machine:

- Operating system.
- Whether `nix` is installed and flakes are enabled.
- Whether it can build `x86_64-linux`.

Tell the user which validation steps from Phase 3 you'll be able to run.

## Phase 1: research, then show a plan

Read these sources and keep the links (in the README or as code comments):

- **MrChromebox docs:**
  - Supported Devices (the LIARA row)
  - Firmware Utility Script
  - Disabling Write Protect
  - Booting Your OS
  - Known Issues
- **chrultrabook docs:** Linux known issues and anything specific to Stoney Ridge.
- **NixOS 26.05 manual:**
  - Installing from the minimal ISO, including Wi-Fi in the installer and whether flakes work there
  - systemd-boot options
- **labwc docs:**
  - `rc.xml`, `menu.xml`, `autostart`, and `environment`
  - Whether labwc updates the D-Bus/systemd activation environment by itself
- **keyd docs, plus WeirdTreeThing/cros-keyboard-map** (a keyd config generator for Chromebook keyboards). Use it as the basis for the keyboard map.
- **The 26.05 option names** for everything in the System spec below.

Then show the user a short plan: the file tree, and any spec items you had to change and why. Wait for their OK before writing files.

## Phase 2: write the repo

### Layout

```
flake.nix, flake.lock
hosts/<hostname>/configuration.nix          # imports modules; sets user and hostname
hosts/<hostname>/hardware-configuration.nix # written by you; mounts by label
modules/base.nix      # nix settings, GC, zram, earlyoom, locale, user, bash, nano, CLI tools, aliases
modules/boot.nix      # systemd-boot, kernel
modules/hardware.nix  # firmware, graphics, keyd, power, Bluetooth, logind
modules/audio.nix     # PipeWire
modules/network.nix   # NetworkManager, Tailscale, firewall, SSH
modules/desktop.nix   # labwc, greetd, portals, fonts, theme, apps, config files
files/                # configs for labwc, waybar, fuzzel, foot, mako, swaylock, nano, plus small helper scripts
scripts/install.sh    # run from the NixOS installer
README.md
docs/post-install-checklist.md
docs/troubleshooting.md
```

Deploying config files:

- Install them system-wide with `environment.etc."xdg/..."` when the app reads `XDG_CONFIG_DIRS`.
- When an app doesn't, pass the file path explicitly, for example on the command line in labwc's autostart.
- Verify each app's lookup behavior. The user can still override anything in `~/.config`.

### Disk layout (scripts/install.sh)

- **Partition table:** GPT.
- **Partition 1:** 1 GiB, FAT32, label `BOOT`, mounted at `/boot` with `umask=0077`.
- **Partition 2:** the rest of the disk, btrfs, label `nixos`, with these subvolumes:
  - `@` → `/`
  - `@home` → `/home`
  - `@nix` → `/nix`
  - `@log` → `/var/log`
- **Mount options:** `compress=zstd:1,noatime`.
- **Swap:** no swap partition; use zram instead.

`hardware-configuration.nix` mounts by `/dev/disk/by-label/...`, so you can write it ahead of time. To catch anything missing, `install.sh` must also:

1. Run `nixos-generate-config --root /mnt --show-hardware-config`.
2. Compare its kernel-module lists (`boot.initrd.availableKernelModules`, `boot.kernelModules`) against the repo's file.
3. Stop with a clear message if the generated config has modules the repo lacks. This matters most for the eMMC controller driver.

`install.sh` safety requirements:

- Take the target disk as a required argument, with no default.
- Print `lsblk -o NAME,SIZE,MODEL,TRAN,RM`.
- Refuse USB or removable devices.
- Require the user to type the full device path to continue.
- Use `set -euo pipefail` and announce each step in plain language.
- Make sure flakes are enabled in the installer (for example via `NIX_CONFIG`), in case the ISO doesn't enable them.

`install.sh` steps, in order:

1. Partition.
2. Format.
3. Create subvolumes.
4. Mount.
5. Copy the repo to `/mnt/home/<user>/nixos-config`.
6. Run the module check described above.
7. Run `nixos-install --flake ...#<hostname> --no-root-passwd`.
8. Set the user's password with `nixos-enter`.
9. Fix the repo's ownership.
10. Print the next steps.

### System spec

**Boot and kernel**
- systemd-boot, with EFI variables writable.
- `configurationLimit = 3`; boot menu timeout about 2 seconds.
- `boot.kernelPackages = pkgs.linuxPackages_latest`.
- `boot.tmp.cleanOnBoot = true`.
- Make sure the fallback path `\EFI\BOOT\BOOTX64.EFI` exists.

**Nix housekeeping**
- Enable flakes and nix-command; `auto-optimise-store`.
- Weekly garbage collection, deleting generations older than 14 days.
- `max-jobs = 1`, `cores = 2`.
- `documentation.nixos.enable = false` (keep man pages).
- Cap journald at about 100 MB.
- Enable `services.fstrim` and a monthly btrfs scrub.

**Memory**
- zram swap (zstd, 50% of RAM).
- earlyoom with desktop notifications.
- Consider a higher `vm.swappiness` suited to zram, and document your choice.

**User and shell**
- One normal user (uid 1000) in `wheel` and `networkmanager`, plus whatever groups brightnessctl, keyd, and the rest actually need. Verify each group; don't guess.
- bash with completion.
- nano as `EDITOR`, with a sensible nanorc: syntax highlighting, line numbers, mouse support.
- Shell aliases:
  - `sysupdate`: `git pull` in `~/nixos-config`, then `sudo nixos-rebuild switch --flake ~/nixos-config#<hostname>`.
  - `sysclean`: delete old generations, collect garbage, then refresh the boot entries.
  - `sysrollback`: switch back to the previous generation.
- CLI tools: git, curl, wget, htop, unzip, zip, file, tree, rsync, man-pages, pciutils, usbutils, alsa-utils, libva-utils, wev, compsize.

**Network**
- NetworkManager, with nm-applet in the tray.
- Wi-Fi passwords must survive reboots even with auto-login and no keyring unlock. Verify how nm-applet stores secrets, prefer system-wide storage, and don't add gnome-keyring.
- Tailscale service enabled. The user runs `sudo tailscale up` once after install.
- Firewall on. Check whether the Tailscale module needs `checkReversePath` adjusted.
- If the user provided an SSH key:
  - OpenSSH reachable only on `tailscale0`
  - key authentication only
  - no root login

**Bluetooth:** enabled, with the blueman applet in the tray.

**Audio:** PipeWire and WirePlumber with ALSA and PulseAudio compatibility, plus rtkit and pavucontrol.

**Graphics and power**
- `hardware.graphics.enable`, redistributable firmware, AMD microcode.
- TLP with default settings. power-profiles-daemon likely has nothing to control on pre-Zen 2 AMD chips; verify, then pick one (the two conflict).
- upower.

**Login (greetd)**
- `initial_session` logs the user straight into labwc at boot.
- `default_session` is tuigreet, shown after logging out.

**Desktop (labwc)**

Use the NixOS labwc module. Autostart:
- the activation-environment update, if labwc doesn't already do it
- swaybg (solid color)
- waybar
- mako
- `nm-applet --indicator`
- blueman-applet
- the polkit_gnome agent
- swayidle

Prefer autostart over systemd user services tied to `graphical-session.target`, unless you confirm labwc activates that target.

- **Waybar**, at the bottom of the screen (familiar from ChromeOS).
  - Left: a launcher button and the taskbar (`wlr/taskbar`).
  - Right: tray, Bluetooth, network, volume (click opens pavucontrol), brightness, battery, clock with a calendar tooltip.
  - Power button: opens a fuzzel menu with Lock, Suspend, Log out, Reboot, Shut down.
- **Launcher:** fuzzel, with a large, readable font.
- **Terminal:** foot.
- **Notifications:** mako, 5-second timeout.
- **Lock and idle**
  - swaylock (requires `security.pam.services.swaylock = {}`).
  - Lock at 5 minutes idle, screen off at about 6 minutes (wlopm), lock before sleep.
  - Closing the lid suspends (logind).
  - The keyboard's power key suspends instead of powering off.
- **Touchpad** (labwc libinput section): tap-to-click, natural scrolling (the ChromeOS default), disable while typing.
- **Portals:**
  - xdg-desktop-portal-wlr for screenshots and screen sharing.
  - xdg-desktop-portal-gtk for file choosers.
  - Write the portal config so the right backend is used under labwc.
- **Look**
  - Adwaita GTK theme, icons, and cursor; enable dconf.
  - Fonts: Noto Sans, Serif, and Mono, plus Noto Color Emoji. No CJK fonts.
  - Display scale 1.0 to start; document how to try 1.25.
- **Right-click desktop menu:** Terminal, Firefox, Thunderbird, Files, Wi-Fi, Bluetooth, Sound, Lock, Log out, Reboot, Shut down.

**Keyboard (keyd plus labwc keybinds), modeled on ChromeOS**

- Top-row keys:
  - Back, Forward, Refresh, Fullscreen, Overview, Brightness −/+, Mute, Volume −/+.
  - Search + top-row key sends F1–F10.
- Navigation:
  - Search+Backspace → Delete
  - Search+Left/Right → Home/End
  - Search+Up/Down → Page Up/Page Down
- Launcher:
  - Tapping Search alone opens the launcher. Use a keyd overload or a labwc on-release binding, whichever works; fall back to Search+Space.
  - The Overview key alone also opens the launcher.
- App shortcuts:
  - Search+Enter and Ctrl+Alt+T → terminal
  - Search+B → Firefox
  - Search+M → Thunderbird
  - Search+E → Files
  - Search+L → lock
- Windows:
  - Alt+[ and Alt+] → snap left/right
  - Alt+= → maximize
  - Alt+Tab → switch windows
  - Search+Q and Alt+F4 → close
- Screenshots (grim, slurp, wl-copy):
  - Search+Shift+S → select a region.
  - Ctrl+Overview → full screen.
  - Save to `~/Pictures/Screenshots` and copy to the clipboard.
- Brightness through brightnessctl; volume through wpctl, capped at 100%.

The key mappings must be verified on the device. Put a `sudo keyd monitor` / `wev` test step in the checklist.

**Apps**
- **Firefox**
  - Policies: disable telemetry, studies, and Pocket; install uBlock Origin; cap the disk cache around 250 MB.
  - Note for the user: YouTube serves VP9/AV1 video, which this GPU can't decode in hardware. Offer an extension that forces H.264, but don't install it without asking.
- **Thunderbird:** use the NixOS module if 26.05 has one; otherwise install the package.
- **Thunar** with gvfs, udisks2, and thunar-volman, for USB drives and trash. Add archive support only if it doesn't pull in Qt.
- **Utilities:** pavucontrol, grim, slurp, wl-clipboard, brightnessctl, wlopm, libnotify, xdg-utils, xdg-user-dirs (to create Downloads, Documents, and Pictures).

## Phase 3: validate, as far as this machine allows

1. Run `nix flake check`.
2. `nix eval` the kernel version. It must be 6.19 or newer.
3. Dry-run build `nixosConfigurations.<hostname>.config.system.build.toplevel`. The "will be built" list may only contain small config derivations (etc files, scripts, systemd units). If it includes linux, firefox, thunderbird, mesa, webkitgtk, gtk, or anything else large, fix the config.
4. If this machine can build `x86_64-linux`, build the system and report its closure size (`nix path-info -Sh`). Flag it if it's over 7 GiB.
5. Optional, if this machine can run it: `nixos-rebuild build-vm`, to check that auto-login starts labwc and Waybar appears.
6. Run `shellcheck` on `install.sh` if it's available.

If some steps can't run here (for example, Windows without WSL, or macOS can't build Linux systems), say so. Then add `nixos-rebuild dry-build` to the README as a step to run on the Chromebook.

## Phase 4: README.md (written for the user)

Use plain language, numbered steps, exact commands, and clearly marked warnings. Sections:

1. **What you need.**
   - Two USB sticks: one for the firmware backup, and one of at least 2 GB for the NixOS installer.
   - The charger.
   - A small Phillips screwdriver.
   - About two hours.
2. **Before you start.** Back up ChromeOS files, because this erases ChromeOS. Confirm the board name LIARA on the Recovery screen.
3. **Enable Developer Mode.** The battery must be connected for this step.
4. **Disable write protection** using the method in MrChromebox's table for LIARA (expected: disconnect the battery and run on the charger).
5. **Flash the UEFI Full ROM firmware** with the Firmware Utility Script.
   - Save the stock firmware backup to USB stick #1 and keep it somewhere safe.
   - Power off from the script, reconnect the battery, then plug in the charger to wake the laptop.
   - A black screen for 20–60 seconds on the first boot is normal.
6. **Make the NixOS 26.05 minimal ISO USB** on the main computer: download link, how to verify the checksum, and a tool for writing it.
7. **Boot the installer.**
   - How to open the firmware boot menu.
   - Connect to Wi-Fi.
   - Clone the repo and run `install.sh`.
8. **First boot.** What to expect; run `sudo tailscale up`; then go through the post-install checklist.
9. **Daily use.**
   - Keyboard shortcut cheat sheet.
   - Connecting to Wi-Fi and Bluetooth.
   - Updating (`sysupdate`) and cleaning up (`sysclean`).
   - Undoing a bad update (the boot menu, or `sysrollback`).
10. **Updating from the main computer over Tailscale** (only if SSH is enabled). Use `nixos-rebuild switch --flake .#<hostname> --target-host <user>@<hostname>` with the correct 26.05 sudo flag. This builds on the main computer and copies the result to the Chromebook.
11. **Upgrading to NixOS 26.11** when 26.05 support ends on 2026-12-31.

## docs/post-install-checklist.md

1. The laptop boots to the desktop with no login prompt.
2. Wi-Fi connects, and still connects after a reboot.
3. `sudo tailscale up` works and `tailscale status` shows the device.
4. Speakers, headphone jack, and microphone work (start at low volume).
5. Every top-row key and shortcut works.
6. Screen brightness changes.
7. Closing and reopening the lid shows the lock screen, and Wi-Fi reconnects.
8. Bluetooth headphones pair and play.
9. A USB stick appears in Thunar.
10. Firefox plays video, and `vainfo` shows the radeonsi driver.
11. `df -h /` and `sudo compsize /nix` show reasonable disk use.
12. Reboot, pick the previous generation from the boot menu, then reboot back to the current one.

## docs/troubleshooting.md

- **No speaker audio**
  1. Check that `uname -r` shows 6.19 or newer.
  2. Check that `aplay -l` lists the ACP sound card, and look at `wpctl status`.
  3. If the card exists but makes no sound, read how chromebook-linux-audio handles Stoney Ridge (UCM configs, modprobe options). Port that declaratively, for example a custom UCM directory exposed to PipeWire/WirePlumber through ALSA's UCM path environment variable.
  4. If still stuck, post on the chrultrabook forum with the board name.
- **No Wi-Fi:** check firmware loading in `journalctl -k`.
- **Wrong keys:** run `sudo keyd monitor` and adjust the keyd config.
- **Firmware problems:**
  - Black screen after flashing.
  - Which key opens the boot menu.
  - How to restore stock firmware from the USB backup (link to MrChromebox's docs).
- **Out of disk space:** run `sysclean`, check sizes with `nix path-info`, and trim the journal.

## Done means

- The repo is complete, and the validation results are reported honestly: what passed and what couldn't be run.
- The closure size is reported, if the system could be built here.
- Any spec items you changed are listed, with reasons.
- The kernel version is confirmed to be 6.19 or newer.
- The work is ready to commit with clear messages, and the user is asked to push it to GitHub.

## Phase 0 answers (2026-10-06)

These were answered and the plan was approved; don't ask again unless something changes.

- User: `derik`, full name Derik.
- Hostname: `liara` (the default).
- Repo: `derikatwork/blackbook` (public).
- SSH key: none for now, so SSH stays off. Add one to `local.sshKeys` in `hosts/liara/configuration.nix` to turn it on.
- Main computer: Linux.
- Defaults accepted: America/Los_Angeles, en_US.UTF-8, US keyboard, light Adwaita theme.

### Decisions made during planning

- `sysupdate` and `sysrollback` use `nixos-rebuild ... --sudo` instead of `sudo nixos-rebuild ...`: evaluation and building run as the user (who owns the git repo), and only activation uses sudo.
- nm-applet and earlyoom's notifier (systembus-notify) are started from labwc's autostart, because labwc doesn't activate `graphical-session.target`.
- labwc 0.9 updates the D-Bus/systemd activation environment itself, so autostart doesn't.
- mako and swaylock don't read `/etc/xdg`; the `start-mako` and `lock-screen` helpers pass `/etc/xdg/...` explicitly unless the user has a `~/.config` copy.
- Not running (removed defaults, not additions): speech-dispatcher service, ModemManager, NixOS's default font set.
