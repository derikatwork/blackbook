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
| Web browser          | Zen Browser (Flatpak)            |
| Email                | Thunderbird                      |
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
base.nix          Main NixOS module: auto-update services, Flatpak + Flathub
common.nix        Shared base (boot splash, fonts, printing, Thunderbird)
desktop.nix       The Openbox / BunsenLabs-style desktop definition
chromebook.nix    Chromebook audio & firmware support (from Nixbook)
installed.nix     allowUnfree + insecure-package predicate (from Nixbook)
channel.sh        Pins the NixOS channel and prunes old generations
install-desktop.sh Non-destructive: switch an existing graphical NixOS to Blackbook
install.sh        Appliance converter: turns a blank minimal NixOS into a Blackbook
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
directory (via `install-desktop.sh`, `install.sh` or `powerwash.sh`).

---

## Installation

There are two installers depending on your starting point. Both just need the
repo cloned to `/etc/blackbook` first:

```sh
nix-shell -p git --run \
  'sudo git clone https://github.com/derikatwork/blackbook.git /etc/blackbook'
```

### On an existing graphical NixOS system (recommended)

If you already have a working NixOS desktop (GNOME, Plasma, etc.) and just want
to switch it to Blackbook's Openbox desktop, run the **non-destructive**
installer as your normal user:

```sh
sh /etc/blackbook/install-desktop.sh
```

It imports `base.nix` into `/etc/nixos/configuration.nix` (backing it up first),
copies the Openbox dotfiles into your home (backing up `~/.config`), rebuilds,
and switches you to the Openbox session. **Your files are left in place.**
Blackbook uses LightDM as the single display manager and force-disables GDM/SDDM,
so the switch is conflict-free; your old desktop stays selectable at login until
you choose to remove it. Email works immediately (Thunderbird), and Zen Browser
installs itself on first boot — Flathub is set up declaratively, so there is no
manual `flatpak remote-add` step.

### On a blank minimal NixOS system (dedicated appliance)

To convert a fresh minimal install into a dedicated Blackbook — the Nixbook
"powerwash the home directory and take over the machine" approach — run:

```sh
sh /etc/blackbook/install.sh
```

This one **wipes the home directory** and rebuilds it from the Blackbook
skeleton, inserts `base.nix`, and installs the Flatpak apps. Only use it on a
machine you intend to hand over as an appliance.

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
