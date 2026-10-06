# The desktop: labwc, auto-login, panel, launcher, apps, look, and the
# config files in ../files/.
{ config, lib, pkgs, ... }:

let
  cfg = config.local;
  labwc = "${config.programs.labwc.package}/bin/labwc";

  # Small helper commands from files/bin, put on the PATH.
  helper = name: pkgs.writeShellScriptBin name (builtins.readFile (../files/bin + "/${name}"));
  helpers = map helper [
    "lock-screen"
    "power-menu"
    "screenshot"
    "start-mako"
  ];

  # The polkit agent is not on the PATH, so its full path is filled in here.
  labwcAutostart =
    builtins.replaceStrings
      [ "@polkitAgent@" ]
      [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ]
      (builtins.readFile ../files/labwc/autostart);
in
{
  # ---- Window manager -----------------------------------------------------
  # The NixOS labwc module also turns on polkit, dconf, XWayland, the
  # swaylock PAM service (security.pam.services.swaylock), and the wlr and
  # gtk portals.
  programs.labwc.enable = true;

  # ---- Login --------------------------------------------------------------
  # At boot, log straight into labwc. After you log out, show tuigreet (a
  # text login screen) to log in again.
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      initial_session = {
        command = labwc;
        user = cfg.username;
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd ${labwc}";
        user = "greeter";
      };
    };
  };

  # ---- Portals (screenshots, screen sharing, file pickers) ----------------
  # labwc sets XDG_CURRENT_DESKTOP=labwc:wlroots, so xdg-desktop-portal reads
  # labwc-portals.conf first. wlr handles screenshots and screen sharing;
  # gtk handles file choosers and everything else.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.labwc = {
      default = [ "wlr" "gtk" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  # ---- Look ---------------------------------------------------------------
  # Light Adwaita theme, icons and cursor for GTK apps. GTK reads these
  # GNOME settings (dconf) on Wayland; settings.ini (below) is the fallback.
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          gtk-theme = "Adwaita";
          icon-theme = "Adwaita";
          cursor-theme = "Adwaita";
          cursor-size = lib.gvariant.mkInt32 24;
          color-scheme = "prefer-light";
          font-name = "Noto Sans 11";
          document-font-name = "Noto Sans 11";
          monospace-font-name = "Noto Sans Mono 11";
        };
      }
    ];
  };

  # Only the Noto fonts (no CJK). This replaces NixOS's default font set.
  fonts = {
    enableDefaultPackages = false;
    packages = [
      pkgs.noto-fonts
      pkgs.noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      monospace = [ "Noto Sans Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # NixOS runs the text-to-speech service (speech-dispatcher) on any
  # desktop by default. Nothing here uses it, so do not run it. (Firefox
  # still ships its library, which is harmless.)
  services.speechd.enable = false;

  # ---- Apps ---------------------------------------------------------------
  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
    };
    # Defaults you can still change in about:config.
    preferencesStatus = "default";
    preferences = {
      # Keep the disk cache to about 250 MB (the value is in KB).
      "browser.cache.disk.smart_size.enabled" = false;
      "browser.cache.disk.capacity" = 256000;
    };
  };

  programs.thunderbird.enable = true;

  # File manager with USB drives (udisks2), trash and network places
  # (gvfs), and right-click "Extract here" (xarchiver, a GTK app, no Qt).
  programs.thunar = {
    enable = true;
    plugins = [
      pkgs.thunar-volman
      pkgs.thunar-archive-plugin
    ];
  };
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  environment.systemPackages =
    (with pkgs; [
      # Desktop pieces
      waybar
      fuzzel
      foot
      mako
      swaybg
      swayidle
      swaylock
      wlopm # turns the screen off and on
      adwaita-icon-theme # icons and the Adwaita cursor

      # Utilities
      xarchiver
      grim # screenshots
      slurp # pick a screen area
      wl-clipboard # wl-copy, wl-paste
      brightnessctl
      libnotify # notify-send
      xdg-utils # xdg-open
      xdg-user-dirs
    ])
    ++ helpers;

  # ---- Config files -------------------------------------------------------
  # Installed system-wide in /etc/xdg. These programs read /etc/xdg (via
  # XDG_CONFIG_DIRS) only when you have no copy in ~/.config, so your own
  # copy always wins. mako and swaylock do not read /etc/xdg; their helpers
  # (start-mako, lock-screen) pass the file on the command line instead.
  environment.etc = {
    "xdg/labwc/rc.xml".source = ../files/labwc/rc.xml;
    "xdg/labwc/menu.xml".source = ../files/labwc/menu.xml;
    "xdg/labwc/environment".source = ../files/labwc/environment;
    "xdg/labwc/autostart".text = labwcAutostart;
    "xdg/waybar/config.jsonc".source = ../files/waybar/config.jsonc;
    "xdg/waybar/style.css".source = ../files/waybar/style.css;
    "xdg/fuzzel/fuzzel.ini".source = ../files/fuzzel/fuzzel.ini;
    "xdg/foot/foot.ini".source = ../files/foot/foot.ini;
    "xdg/mako/config".source = ../files/mako/config;
    "xdg/swaylock/config".source = ../files/swaylock/config;
    "xdg/gtk-3.0/settings.ini".source = ../files/gtk-3.0/settings.ini;
    "xdg/gtk-4.0/settings.ini".source = ../files/gtk-4.0/settings.ini;

    # xdg-user-dirs-update (run at login) creates only these folders in your
    # home folder; the other standard folders just point to ~.
    "xdg/user-dirs.defaults".text = ''
      DOWNLOAD=Downloads
      DOCUMENTS=Documents
      PICTURES=Pictures
    '';
  };
}
