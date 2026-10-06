# Troubleshooting

Open a terminal with **Ctrl+Alt+T**. If the desktop doesn't start at all,
press **Ctrl+Alt+Forward** for a text console (log in with your user name and
password), or boot an older entry from the boot menu (README section 9).

- [No speaker audio](#no-speaker-audio)
- [No Wi-Fi](#no-wi-fi)
- [Wrong keys](#wrong-keys)
- [Firmware problems](#firmware-problems)
- [Out of disk space](#out-of-disk-space)
- [Other problems](#other-problems)

---

## No speaker audio

1. **Check the kernel is 6.19 or newer.** Stoney Ridge speaker and microphone
   support needs Linux 6.19+:

   ```
   uname -r
   ```

   If it shows 6.18 or older, `boot.kernelPackages = pkgs.linuxPackages_latest;`
   is missing from `modules/boot.nix`, or you booted an old entry.

2. **Check the sound card exists**, and what PipeWire sees:

   ```
   aplay -l
   wpctl status
   ```

   `aplay -l` should list an AMD ACP card (the name starts with `acp`). In
   `wpctl status`, check that a speaker output exists under **Sinks**, isn't
   muted, and is the default (marked with `*`). Click the volume in the panel
   to open Volume Control and check the **Output Devices** and
   **Configuration** tabs.

   Kernel messages about the sound card:

   ```
   journalctl -k -b | grep -i -E 'acp|da7219|max98357|snd'
   ```

3. **If the card exists but makes no sound,** read how
   [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
   handles Stoney Ridge (`setup-audio`, the `st` platform), and port what it
   does into `modules/audio.nix`. Don't run that script on NixOS; it can't
   change NixOS's read-only system files.

   When this repo was written, that script did three things for Stoney Ridge:
   warn that the kernel must be 6.19+, install its UCM files, and install two
   WirePlumber settings. The WirePlumber settings are already in
   `modules/audio.nix`. Its UCM repository
   ([alsa-ucm-conf-cros](https://github.com/WeirdTreeThing/alsa-ucm-conf-cros))
   had no Stoney Ridge files; this card uses the normal upstream UCM files.

   If you ever need custom UCM files, the NixOS way is to package a folder of
   UCM files and point ALSA at it with the `ALSA_CONFIG_UCM2` environment
   variable, for both PipeWire and WirePlumber. A sketch for
   `modules/audio.nix`:

   ```nix
   let
     ucm = pkgs.runCommand "alsa-ucm-custom" { } ''
       mkdir -p $out
       cp -r ${pkgs.alsa-ucm-conf}/share/alsa/ucm2 $out/ucm2
       chmod -R u+w $out/ucm2
       # copy your changed .conf files over the ones in $out/ucm2 here
     '';
   in {
     systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = "${ucm}/ucm2";
     systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = "${ucm}/ucm2";
   }
   ```

   This is a starting point, not tested on this laptop. A module option
   (modprobe settings) would go in `boot.extraModprobeConfig`.

4. **Still stuck?** Ask on the [chrultrabook forum](https://forum.chrultrabook.com/).
   Say the board name is **LIARA** (Lenovo 14e, AMD Stoney Ridge), your
   `uname -r`, and the output of `aplay -l` and `wpctl status`.

## No Wi-Fi

1. Is there a Wi-Fi device at all?

   ```
   nmcli device status
   ```

2. Check whether the Wi-Fi firmware loaded (look for "firmware" errors):

   ```
   journalctl -k -b | grep -i -E 'firmware|wlan|wifi|ath|rtw|iwl|mt7'
   ```

   Wi-Fi firmware comes from `hardware.enableRedistributableFirmware = true;`
   in `modules/hardware.nix`. Make sure it's still there.

3. Is Wi-Fi switched off (rfkill)?

   ```
   rfkill list
   nmcli radio wifi on
   ```

4. To connect without the tray icon: `nmtui`.

## Wrong keys

1. See what a key actually sends:

   ```
   sudo keyd monitor
   ```

   Press the key, read the name, and stop with **Ctrl+C**.
2. Edit `files/keyd/chromebook.conf` in the repo. The left side of `=` is the
   key name from `keyd monitor`, the right side is what to send.
3. Apply it with `sysupdate` (after pushing) or
   `nixos-rebuild switch --sudo --flake ~/nixos-config#liara`.
4. To see what the desktop receives after keyd, run `wev` and press the key.
   labwc's shortcuts are in `files/labwc/rc.xml`.

If tapping Search doesn't open the launcher, use **Search+Space** or the
**Overview** key; both always work.

## Firmware problems

### Black screen after flashing

The first start after flashing shows a black screen for **20–60 seconds**
(up to 2 minutes) while the firmware trains the memory. This is normal. Don't
turn it off.

If nothing happens after 2 full minutes:

1. Hold **Power** for 10 seconds to turn it off, then press Power again.
2. Try a hard reset: hold **Refresh** and press **Power**.
3. See MrChromebox's [Known Issues](https://docs.mrchromebox.tech/docs/known-issues.html)
   ("Device Won't Boot After Firmware Flash") and
   [Unbricking](https://docs.mrchromebox.tech/docs/support/unbricking/).

If you see `Shell>`, that is the firmware's EFI shell (no system found to
boot). Type `exit` and press Enter to get to the menu.

### Which key opens the boot menu

Press **Esc** when the rabbit logo appears at startup, then choose
**Boot Menu** (to start from a USB stick) or **Boot Manager** (to change the
order). Source: [Booting Your OS](https://docs.mrchromebox.tech/docs/firmware/booting.html).

### The laptop doesn't boot NixOS, but the USB installer works

The boot entry may be lost. The firmware also tries `\EFI\BOOT\BOOTX64.EFI`
on its own, which this setup keeps in place. To repair the boot loader from
the installer USB:

```
sudo mount -o subvol=@ /dev/disk/by-label/nixos /mnt
sudo mount -o subvol=@nix /dev/disk/by-label/nixos /mnt/nix
sudo mount /dev/disk/by-label/BOOT /mnt/boot
sudo nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
```

### Putting the original ChromeOS firmware back

You need the backup from USB stick #1 (`BACKUP-LIARA-....rom`), and write
protection must be off again (battery disconnected, running on the charger,
see README section 4). Then follow MrChromebox's
[Restoring Stock Firmware](https://docs.mrchromebox.tech/docs/reverting/flashing-stock.html):

1. Start Linux. NixOS itself works, or the NixOS installer USB (connect Wi-Fi
   with `nmtui`).
2. Run the Firmware Utility Script:

   ```
   cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
   ```

3. Choose **Restore Stock Firmware**, then **Restore from USB backup**, and pick
   the backup file on USB stick #1.
4. Reboot, then reinstall ChromeOS with a
   [ChromeOS Recovery USB](https://docs.mrchromebox.tech/docs/reverting/recovery-usb.html).

## Out of disk space

1. Delete old versions and free their space:

   ```
   sysclean
   ```

2. See what uses the space:

   ```
   df -h /
   sudo compsize /nix
   nix path-info -Sh /run/current-system
   du -sh ~/* ~/.cache 2>/dev/null | sort -h
   ```

   `nix path-info -Sh` shows the size of the whole system (before
   compression). Firefox's cache (`~/.cache/mozilla`) is limited to about
   250 MB.

3. Trim the system log:

   ```
   journalctl --disk-usage
   sudo journalctl --vacuum-size=50M
   ```

## Other problems

- **Desktop doesn't start after login:** press **Ctrl+Alt+Forward**, log in,
  and read the errors:

  ```
  journalctl -b -u greetd
  journalctl --user -b
  ```

  Boot an older entry from the boot menu to get back to a working version.
- **A program in the panel or tray is missing:** start it from a terminal to
  see its error (for example `waybar` or `nm-applet --indicator`). They are
  started by `/etc/xdg/labwc/autostart`.
- **No notifications:** `notify-send test hello` should show one at the bottom
  right. If not, run `start-mako` in a terminal and read the error.
- **Lock screen doesn't accept the password:** type your user password (the
  one you chose during the install) and press Enter. If the lock screen is
  stuck, switch to a text console (**Ctrl+Alt+Forward**), log in, and run
  `sudo systemctl restart greetd`. That ends the desktop session (unsaved work
  is lost) and shows the login screen.
- **"Out of memory" notification:** earlyoom closed the biggest program to
  keep the laptop responsive. Close some Firefox tabs.
