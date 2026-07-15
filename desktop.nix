# BunsenLabs-style Openbox desktop for Blackbook
#
# Recreates the classic BunsenLabs/CrunchBang session on NixOS:
#   Openbox + tint2 panel + jgmenu + conky + picom + dunst
#   Thunar file manager, xfce4-terminal, Geany, dark GTK theme
#
# Per-user configuration (openbox rc.xml, tint2rc, jgmenu, conky, picom,
# GTK settings) lives in ./config/config and is copied to /etc/skel and to
# each user's home by the installer (see base.nix and install.sh).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # BunsenLabs-style logout dialog (stand-in for bl-exit)
  blackbook-exit = pkgs.writeShellScriptBin "blackbook-exit" ''
    ${pkgs.yad}/bin/yad --title="Exit Blackbook" --center --on-top --borders=12 \
      --window-icon=system-shutdown --image=system-shutdown --image-on-top \
      --text="What would you like to do?" \
      --buttons-layout=spread \
      --button="Cancel!window-close:0" \
      --button="Log Out!system-log-out:10" \
      --button="Suspend!media-playback-pause:11" \
      --button="Reboot!view-refresh:12" \
      --button="Shutdown!system-shutdown:13"
    ret=$?
    case "$ret" in
      10) ${pkgs.openbox}/bin/openbox --exit ;;
      11) systemctl suspend ;;
      12) systemctl reboot ;;
      13) systemctl poweroff ;;
    esac
  '';

  # Screenshot to ~/Pictures with a notification (stand-in for bl-image scripts)
  blackbook-screenshot = pkgs.writeShellScriptBin "blackbook-screenshot" ''
    mkdir -p "$HOME/Pictures"
    file="$HOME/Pictures/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    ${pkgs.scrot}/bin/scrot "$@" "$file" &&
      ${pkgs.libnotify}/bin/notify-send -i camera-photo "Screenshot saved" "$file"
  '';
in
{
  # X11 with Openbox as a standalone window manager
  services.xserver.enable = true;
  services.xserver.windowManager.openbox.enable = true;

  # LightDM with a dark GTK greeter, matching the session theme
  services.xserver.displayManager.lightdm = {
    enable = lib.mkDefault true;
    greeters.gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };
  };
  services.displayManager.defaultSession = lib.mkDefault "none+openbox";

  # Audio via PipeWire (also required by chromebook.nix audio fixes)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  networking.networkmanager.enable = true;

  # Apply the dark GTK theme session-wide (covers GTK2/GTK3 apps that don't
  # read the per-user gtk-3.0/settings.ini, e.g. some launched from tint2).
  environment.sessionVariables = {
    GTK_THEME = "Adwaita-dark";
    XCURSOR_THEME = "Adwaita";
  };

  # Thunar with archive/removable-media integration, like BunsenLabs
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-media-tags-plugin
      thunar-volman
    ];
  };
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.upower.enable = true;

  # PolicyKit authentication agent for the Openbox session
  security.polkit.enable = true;
  systemd.user.services.polkit-mate-authentication-agent-1 = {
    description = "PolicyKit MATE authentication agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.mate.mate-polkit}/libexec/polkit-mate-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # Match Qt applications to the dark GTK theme
  qt = {
    enable = true;
    platformTheme = "gtk2";
    style = "gtk2";
  };

  environment.systemPackages = with pkgs; [
    # Session components
    obconf
    tint2
    jgmenu
    conky
    picom
    dunst
    nitrogen
    hsetroot
    xcape
    light-locker
    yad

    # Applications (the BunsenLabs core set)
    xfce.xfce4-terminal
    xfce.xfce4-power-manager
    xfce.xfce4-taskmanager
    xfce.ristretto
    xfce.mousepad
    geany
    xarchiver
    evince
    gmrun
    gsimplecal
    pavucontrol
    volumeicon
    networkmanagerapplet
    scrot
    brightnessctl
    lxappearance
    xorg.xsetroot
    xorg.xrandr

    # Theming
    gnome-themes-extra
    papirus-icon-theme
    adwaita-icon-theme

    # Helper scripts
    blackbook-exit
    blackbook-screenshot
  ];
}
