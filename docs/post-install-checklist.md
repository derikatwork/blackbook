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

- [ ] **Raw keys (what the keyboard itself sends).** keyd normally takes over
  the keyboard, so stop it for a moment. While it is stopped, the top row
  sends plain F-keys or media keys.

  ```
  sudo systemctl stop keyd
  sudo keyd monitor
  ```

  The keyboard shows as `AT Translated Set 2 keyboard`. Press each top-row
  key, left to right. You should see either `f1` … `f10`, or `back`,
  `forward`, `refresh`, `zoom`, `scale`, `brightnessdown`, `brightnessup`,
  `mute`, `volumedown`, `volumeup`. Write down anything different. Then press
  **Ctrl+C** and start keyd again:

  ```
  sudo systemctl start keyd
  ```

- [ ] **Remapped keys (what keyd sends on).** With keyd running, run
  `sudo keyd monitor` again and watch the lines from `keyd virtual keyboard`.
  The top row, left to right, should show `back`, `forward`, `refresh`,
  `f11`, `scale`, `brightnessdown`, `brightnessup`, `mute`, `volumedown`,
  `volumeup`. With Search held, they should show `f1` … `f10`. **Ctrl+C**
  stops it.

- [ ] **What apps receive.** Run `wev` and press keys inside its window.
  Back, Forward and Refresh show as `XF86Back`, `XF86Forward`, `XF86Reload`,
  and Search + top-row key as `F1` … `F10`. Fullscreen, Overview, brightness,
  mute and volume are desktop shortcuts, so they act straight away and `wev`
  shows nothing for them; that is expected. Close `wev` with **Search+Q**.

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
- [ ] Search+Q and Alt+Fullscreen (sends Alt+F4) close a window
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

Right after installing there is only one version, so first make a second one
with a small, harmless change:

- [ ] Change the desktop background color: in `~/nixos-config/files/labwc/autostart`,
  change `#3b5b74` on the `swaybg` line to another color, for example
  `#4a6b54`. Then apply it:

  ```
  nano ~/nixos-config/files/labwc/autostart
  nixos-rebuild switch --sudo --flake ~/nixos-config#liara
  nixos-rebuild list-generations
  ```

  The last command should now list **2** generations. (The new color shows
  after you log out and back in. You can undo the change later with
  `git -C ~/nixos-config checkout files/labwc/autostart`.)
- [ ] Reboot. While the boot menu shows (2 seconds), press **↓** to stop the
  countdown. Pick the **second NixOS entry** (the older one; not "Reboot Into
  Firmware Interface") and press Enter. The desktop starts with the old
  color.
- [ ] Reboot again and let it start the first (newest) entry.

Done. 🎉
