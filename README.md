# Blackbook

**Convert an old computer into a lightweight, durable, auto-updating NixOS
machine with a classic Openbox desktop.**

Blackbook is a fork of the excellent
[Nixbook](https://github.com/mkellyxp/nixbook) project. It keeps Nixbook's
set-and-forget philosophy — automatic weekly OS updates, Flatpak app
management, generation rollbacks, Chromebook support — but replaces the
Cinnamon desktop with a **BunsenLabs-style Openbox session** in the spirit of
[BunsenLabs](https://github.com/BunsenLabs) / CrunchBang.

The result is a fast, low-resource desktop that runs comfortably on very old
hardware while still updating itself automatically.

---

## The desktop

Instead of a full desktop environment, Blackbook assembles a classic,
lightweight stack:

| Component            | Program                          |
|----------------------|----------------------------------|
| Window manager       | Openbox                          |
| Panel                | tint2 (launchers, tasks, tray, clock, power) |
| Application menu     | jgmenu (Super key / panel button / right-click) |
| Compositor           | picom                            |
| Notifications        | dunst                            |
| Wallpaper            | nitrogen                         |
| System info overlay  | conky (also shows the shortcut cheatsheet) |
| File manager         | Thunar                           |
| Terminal             | xfce4-terminal                   |
| Text editor          | Geany                            |
| Login manager        | LightDM (dark GTK greeter)       |
| Theme                | Adwaita-dark + Papirus-Dark icons |

### Keyboard shortcuts (BunsenLabs scheme)

| Shortcut               | Action              |
|------------------------|---------------------|
| `Super`                | Main menu           |
| `Super` + `Tab`        | Window list         |
| `Super` + `t`          | Terminal            |
| `Super` + `w`          | Web browser         |
| `Super` + `f`          | File manager        |
| `Super` + `e`          | Text editor         |
| `Super` + `m`          | Image viewer        |
| `Super` + `v`          | Volume control      |
| `Super` + `h`          | Task manager        |
| `Super` + `l`          | Lock screen         |
| `Super` + `x`          | Log out / shutdown  |
| `Alt` + `F2`           | Run program         |
| `Print`                | Screenshot to `~/Pictures` |
| `Alt` + `Tab`          | Switch windows      |
| `Alt` + `F4`/`F5`/`F6` | Close / minimize / maximize |
| `Super` + arrow        | Tile to half screen |
| `Super` + `Alt` + arrow| Tile to quarter screen |

---

## Repository layout

```
base.nix          Main NixOS module: auto-update services, Flatpak apps
common.nix        Shared base (boot splash, fonts, printing, packages)
desktop.nix       The Openbox / BunsenLabs-style desktop definition
chromebook.nix    Chromebook audio & firmware support (from Nixbook)
installed.nix     allowUnfree + insecure-package predicate (from Nixbook)
channel.sh        Pins the NixOS channel and prunes old generations
install.sh        One-shot converter: turns a NixOS install into a Blackbook
update.sh         Manual "update & reboot"
repair.sh         Escape hatch for broken Flatpak/rebuilds
powerwash.sh      Factory reset (wipe user data, reinstall apps)
list-generations.sh
config/config/     Per-user dotfiles copied to ~/.config on install
  openbox/         rc.xml (keybinds), menu.xml, autostart
  tint2/tint2rc    Panel
  jgmenu/          jgmenurc, prepend.csv
  conky/conky.conf System info + shortcut cheatsheet
  dunst/dunstrc    Notifications
  gtk-3.0/         Dark theme settings
  picom.conf       Compositor
  user-dirs.dirs
config/desktop/    Files copied to ~/Desktop (Welcome.txt)
```

The desktop configuration files live in `config/config` and are copied both
to `/etc/skel` (for new users, via `base.nix`) and to the current user's home
directory (via `install.sh` / `powerwash.sh`), exactly as Nixbook does.

---

## Installation

Blackbook is applied on top of an existing NixOS installation (typically the
graphical installer, same as Nixbook). On the target machine:

```sh
sudo git clone https://github.com/derikatwork/blackbook.git /etc/blackbook
sh /etc/blackbook/install.sh
```

The installer will:

1. Set up the home directory skeleton and copy the desktop config.
2. Insert `/etc/blackbook/base.nix` into `/etc/nixos/configuration.nix`.
3. Add the Flathub remote and rebuild the system.
4. Install Chrome, Zoom and LibreOffice as Flatpaks and reboot.

To enable automatic login (recommended for single-user machines), add to
`/etc/nixos/configuration.nix`:

```nix
services.displayManager.autoLogin = {
  enable = true;
  user = "user"; # your username
};
```

---

## Updates & maintenance

* **Automatic:** Blackbook pulls this repo and runs `nixos-rebuild boot
  --upgrade` weekly (Monday), with config/Flatpak refreshes Tue–Sun. Reboot
  when notified to apply.
* **Manual update:** menu → *System → Update & Reboot* (runs `update.sh`).
* **Rollback:** old generations are retained (pruned by free space in
  `channel.sh`) and selectable from the boot menu.
* **Factory reset:** menu → *System → Powerwash* (runs `powerwash.sh`).

---

## Customising the desktop

* **Menu entries:** edit `config/config/jgmenu/prepend.csv` (jgmenu) and
  `config/config/openbox/menu.xml` (right-click fallback menu).
* **Keybindings / window behaviour:** edit
  `config/config/openbox/rc.xml`, or use `obconf`.
* **Panel:** edit `config/config/tint2/tint2rc`, or use `tint2conf`.
* **Autostart apps:** edit `config/config/openbox/autostart`.
* **Theme:** run `lxappearance`, or edit `config/config/gtk-3.0/settings.ini`.
* **Wallpaper:** run `nitrogen` and pick an image; it is restored on login.

Existing users pick up changes to `/etc/skel` only on account creation; to
refresh your own config, copy from `/etc/blackbook/config/config` into
`~/.config` (a Powerwash does this wholesale).

---

## Credits

* [Nixbook](https://github.com/mkellyxp/nixbook) by Michael Kelly — the base
  NixOS system, auto-update machinery and Chromebook support this project
  builds on.
* [BunsenLabs](https://github.com/BunsenLabs) — the Openbox desktop design,
  menu structure and keybinding scheme that this configuration recreates.

## License

MIT — see [LICENSE](LICENSE).
