# Post-install checklist

Go through this after the first boot. Open a terminal with **Ctrl+Alt+T** for
the commands. If something fails, see [troubleshooting.md](troubleshooting.md).

## 1. Boots to the desktop with no login prompt

- [ ] After the 2-second boot menu, the desktop appears without asking for a
  password, with the panel at the bottom.
- [ ] The kernel is 6.19 or newer (this prints the version, for example `7.2.9`):

  ```
  uname -r
  ```

- [ ] The fallback boot file exists (this should print `OK`):

  ```
  sudo test -f /boot/EFI/BOOT/BOOTX64.EFI && echo OK
  ```

## 2. Wi-Fi connects, also after a reboot

- [ ] Click the Wi-Fi tray icon and connect (if you aren't connected already).
- [ ] Reboot. Wi-Fi reconnects by itself, without asking for the password.

  ```
  nmcli device status
  ```

## 3. Tailscale

- [ ] `sudo tailscale up` worked and you logged in through the link.
- [ ] `tailscale status` lists **liara** (and your other devices).

## 4. Speakers, headphone jack, microphone

> ⚠️ Start with the volume **low** (press Volume down a few times first).

- [ ] Speakers: play a test sound.

  ```
  speaker-test -c 2 -t wav -l 1
  ```

  You should hear "Front Left", "Front Right". (Or play a YouTube video.)
- [ ] Headphones: plug them in. Sound moves to the headphones.
- [ ] Microphone: click the volume in the panel (opens Volume Control), go to
  **Input Devices**, and talk. The level bar should move.
- [ ] `wpctl status` lists the sound card under **Audio → Sinks**.

## 5. Every top-row key and shortcut

First check what the keys send, then that the shortcuts work.

- [ ] Run `sudo keyd monitor` and press each top-row key, then Search + each
  top-row key. Write down anything odd. **Ctrl+C** stops it.

  The keyboard should appear as `AT Translated Set 2 keyboard` (or `cros_ec`).
  For each top-row key you see the original key (`f1` … `f10`, or `back`,
  `forward`, …) and then what keyd sends.

- [ ] Run `wev`, then press keys inside its window to see the names the
  desktop receives (for example `XF86Back`, `F1`, `XF86LaunchA`). Close it with
  **Search+Q**.

Then try each one (see the table in README section 9):

- [ ] Back / Forward / Refresh in Firefox
- [ ] Fullscreen key makes a window fullscreen and back
- [ ] Overview key opens the launcher
- [ ] Brightness down / up
- [ ] Mute, Volume down / up (the volume stops at 100%)
- [ ] Search + top-row key gives F1–F10 (for example **Search+Refresh** = F3
  opens Find in Firefox)
- [ ] Tap Search alone → launcher; Search+Space → launcher
- [ ] Search+Backspace = Delete; Search+←/→ = Home/End; Search+↑/↓ = Page Up/Down
- [ ] Search+Enter and Ctrl+Alt+T → terminal
- [ ] Search+B → Firefox, Search+M → Thunderbird, Search+E → Files
- [ ] Search+L → lock screen (type your password and press Enter to unlock)
- [ ] Alt+[ and Alt+] snap left/right; Alt+= maximizes; Alt+Tab switches
- [ ] Search+Q and Alt+F4 close a window
- [ ] Search+Shift+S → drag to pick an area; Ctrl+Overview → whole screen.
  Both save to `~/Pictures/Screenshots` and copy to the clipboard.
- [ ] Power key → suspends (press it again, or open the lid, to wake)

## 6. Screen brightness

- [ ] The Brightness keys change brightness, and scrolling on ☀ in the panel
  too.

  ```
  brightnessctl
  ```

## 7. Lid: lock screen and Wi-Fi

- [ ] Close the lid and wait 10 seconds. Open it: the **lock screen** shows.
- [ ] After unlocking, Wi-Fi reconnects within a few seconds.
- [ ] Leave the laptop alone for 5 minutes: the screen locks; at 6 minutes the
  screen turns off. Touching a key turns it back on.

## 8. Bluetooth headphones

- [ ] Click the Bluetooth tray icon → **Search**, put the headphones in pairing
  mode, and pair them.
- [ ] Sound plays through them (switch the output in Volume Control if needed).

## 9. USB stick in Thunar

- [ ] Plug in a USB stick. It appears in the left side of **Files** (Search+E).
- [ ] Open it, copy a file, and use the eject button before unplugging.

## 10. Video and hardware decoding

- [ ] Firefox plays a video (for example on YouTube).
- [ ] `vainfo` mentions the **radeonsi** driver:

  ```
  vainfo 2>&1 | grep -i driver
  ```

- [ ] uBlock Origin shows in Firefox's extensions menu (puzzle piece icon).

## 11. Disk space

- [ ] Reasonable disk use: with this system, `/` should show a few GB used.

  ```
  df -h /
  sudo compsize /nix
  ```

  `compsize` shows how much space compression saves (the "Disk Usage" column
  is the real space used).

## 12. Boot an older version and come back

- [ ] Run `sysupdate` once (even with no changes, it makes sure updating
  works).
- [ ] Reboot. While the boot menu shows (2 seconds), press **↓** to stop the
  countdown. Pick the second entry and press Enter. The desktop starts.
- [ ] Reboot again and let it start the first (newest) entry.

Done. 🎉
