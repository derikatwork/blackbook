# Blackbook base configuration
# Adapted from Nixbook's base.nix (https://github.com/mkellyxp/nixbook):
# auto-updating NixOS + flatpak apps, with a BunsenLabs-style Openbox desktop.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ## Notify Users Script
  notifyUsersScript = pkgs.writeScript "notify-users.sh" ''
    set -eu

    title="$1"
    body="$2"

    users=$(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '{print $1}' | while read session; do
      loginctl show-session "$session" -p Name | cut -d'=' -f2
    done | sort -u)

    for user in $users; do
      [ -n "$user" ] || continue
      uid=$(id -u "$user") || continue
      [ -S "/run/user/$uid/bus" ] || continue

      # Send notification
      ${pkgs.sudo}/bin/sudo -u "$user" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        ${pkgs.libnotify}/bin/notify-send "$title" "$body" || true

      # Fix for gnome software nagging user
      ${pkgs.sudo}/bin/sudo -u "$user" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        ${pkgs.dconf}/bin/dconf write /org/gnome/software/flatpak-updates false || true

    done
  '';

  ## Update Git and Channel Script
  updateGitScript = pkgs.writeScript "update-git.sh" ''
    set -eu

    # Update blackbook configs
    ${pkgs.git}/bin/git -C /etc/blackbook reset --hard
    ${pkgs.git}/bin/git -C /etc/blackbook clean -fd
    ${pkgs.git}/bin/git -C /etc/blackbook pull --rebase

  '';

  ## Install Flatpak Apps Script
  installFlatpakAppsScript = pkgs.writeScript "install-flatpak-apps.sh" ''
    set -eu

    if ${pkgs.flatpak}/bin/flatpak list --app | ${pkgs.gnugrep}/bin/grep -q "app.zen_browser.zen"; then
      echo "Flatpaks already installed"
    else

      # Install Flatpak applications
      ${notifyUsersScript} "Installing Zen Browser" "Please wait while we install Zen Browser..."
      ${pkgs.flatpak}/bin/flatpak install flathub app.zen_browser.zen -y

      # Dark GTK theme for flatpak apps, matching the Openbox session
      ${pkgs.flatpak}/bin/flatpak install flathub org.gtk.Gtk3theme.Adwaita-dark -y || true

      ${notifyUsersScript} "Installing Applications Complete" "Please log out or restart to start using Blackbook and its applications!"
    fi

  '';
in
{
  imports = [
    ./common.nix
    ./installed.nix
  ];

  xdg.portal.enable = true;
  xdg.portal.config.common.default = "gtk";
  environment.systemPackages = with pkgs; [
    gnugrep
    dconf
    gnome-software
    flatpak
    xdg-desktop-portal
    xdg-desktop-portal-gtk
  ];

  # dconf is needed for gnome-software and the flatpak-update nag fix
  programs.dconf.enable = true;

  system.activationScripts.populateSkel = {
    text = ''
      mkdir -p /etc/skel/.config
      mkdir -p /etc/skel/Desktop

      cp -rT /etc/blackbook/config/config /etc/skel/.config
      cp -rT /etc/blackbook/config/desktop /etc/skel/Desktop

      chmod -R 644 /etc/skel/.config
      chmod -R 644 /etc/skel/Desktop
      find /etc/skel -type d -exec chmod 755 {} \;
    '';
    deps = [ ];
  };

  services.flatpak.enable = true;

  # Declaratively ensure the Flathub remote is configured system-wide.
  # (The stock services.flatpak module does not add remotes, so this oneshot
  # takes the place of the manual `flatpak remote-add` the installer used to
  # run - meaning a fresh or reinstalled machine sets it up by itself.)
  systemd.services."add-flathub-remote" = {
    script = ''
      set -eu
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    after = [
      "network-online.target"
      "flatpak-system-helper.service"
    ];
    wants = [ "network-online.target" ];
    before = [ "install-flatpak-apps.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  # Install Flatpak Applications Service
  systemd.services."install-flatpak-apps" = {
    script = ''
      set -eu
      ${installFlatpakAppsScript}
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Restart = "on-failure";
      RestartSec = "30s";
    };

    after = [
      "network-online.target"
      "flatpak-system-helper.service"
      "add-flathub-remote.service"
    ];
    wants = [
      "network-online.target"
      "add-flathub-remote.service"
    ];
    wantedBy = [ "multi-user.target" ];
  };

  # Auto update config, flatpak and channel
  systemd.timers."auto-update-config" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Tue..Sun";
      Persistent = true;
      Unit = "auto-update-config.service";
    };
  };

  systemd.services."auto-update-config" = {
    script = ''
      set -eu

      ${updateGitScript}

      /etc/blackbook/channel.sh

      # Flatpak Updates
      ${pkgs.flatpak}/bin/flatpak update --noninteractive --assumeyes
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Restart = "on-failure";
      RestartSec = "30s";
      CPUWeight = "20";
      IOWeight = "20";
    };

    after = [
      "network-online.target"
      "graphical.target"
    ];
    wants = [ "network-online.target" ];
  };

  # Auto Upgrade NixOS
  systemd.timers."auto-upgrade" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon";
      Persistent = true;
      Unit = "auto-upgrade.service";
    };
  };

  systemd.services."auto-upgrade" = {
    script = ''
      set -eu
      export PATH=${pkgs.nixos-rebuild}/bin:${pkgs.nix}/bin:${pkgs.systemd}/bin:${pkgs.util-linux}/bin:${pkgs.coreutils-full}/bin:$PATH
      export NIX_PATH="nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos nixos-config=/etc/nixos/configuration.nix"

      ${updateGitScript}

      ${notifyUsersScript} "Starting System Updates" "System updates are installing in the background.  You can continue to use your computer while these are running."

      ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --upgrade

      ${notifyUsersScript} "System Updates Complete" "Updates are complete!  Simply reboot the computer whenever is convenient to apply updates."
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Restart = "on-failure";
      RestartSec = "30s";
      CPUWeight = "20";
      IOWeight = "20";
    };

    after = [
      "network-online.target"
      "graphical.target"
    ];
    wants = [ "network-online.target" ];
  };
}
