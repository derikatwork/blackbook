# Automatic updates. Once a day the laptop downloads the newest NixOS 26.05
# packages and installs them for the next restart, like ChromeOS does.
# Nothing changes while you work; a notification asks you to restart.
# To turn this off, add `system.autoUpgrade.enable = false;` to
# hosts/liara/configuration.nix.
#
# Only package versions change. The settings in this repo stay exactly as
# they are on the laptop now: each system keeps a copy of the repo it was
# built from (local.configSource), and the update rebuilds that copy with
# the newest commit of the nixpkgs branch named in flake.nix. Changes to the
# repo itself still take effect only when you run sysupdate.
{ config, lib, pkgs, ... }:

let
  cfg = config.local;

  # The branch in flake.nix, for example "github:NixOS/nixpkgs/nixos-26.05".
  # Updates use its newest commit instead of the older one recorded in
  # flake.lock, so that one line in flake.nix stays the only thing to change
  # when moving to the next NixOS release.
  nixpkgsBranch = (import ../flake.nix).inputs.nixpkgs.url;

  updateCheck = pkgs.writeShellScriptBin "update-check" (
    builtins.replaceStrings [ "@nixosRebuild@" ] [ "${config.system.build.nixos-rebuild}/bin/nixos-rebuild" ] (
      builtins.readFile ../files/bin/update-check
    )
  );

  # Show a desktop notification (through systembus-notify, which the labwc
  # autostart starts, the same way earlyoom's notifications work). A
  # notification that can't be sent doesn't count as an error.
  notify = summary: body:
    "${pkgs.dbus}/bin/dbus-send --system / net.nuetzlich.SystemNotifications.Notify "
    + lib.escapeShellArgs [ "string:${summary}" "string:${body}" ]
    + " || true";

  # Is a newer system installed than the one running? (/run/current-system
  # changes only after a restart, or with sysupdate.)
  updatePending = ''[ "$(readlink -f /nix/var/nix/profiles/system)" != "$(readlink -f /run/current-system)" ]'';
  restartNotice = notify "Update ready" "Restart the laptop to finish updating.";
in
{
  options.local.configSource = lib.mkOption {
    type = lib.types.path;
    description = "This repo, as the copy in /nix/store the system was built from. Set by flake.nix.";
  };

  config = {
    environment.systemPackages = [ updateCheck ];

    system.autoUpgrade = {
      enable = lib.mkDefault true;
      flake = "path:${cfg.configSource}#${config.networking.hostName}";
      flags = [ "--override-input" "nixpkgs" nixpkgsBranch ];
      # --upgrade updates NixOS channels, which this flake doesn't use.
      upgrade = false;
      # Install for the next start instead of switching the running system,
      # so Wi-Fi, Bluetooth and the desktop aren't restarted while you work.
      operation = "boot";
      # The laptop is usually asleep at 04:40; the update then runs soon
      # after it wakes up or starts (the timer is persistent by default).
      dates = "04:40";
    };

    systemd.services = lib.mkIf config.system.autoUpgrade.enable {
      nixos-upgrade = {
        serviceConfig = {
          ExecCondition = [
            # Keep at most one update waiting for a restart. That way the boot
            # menu (3 entries) always still has the version that is running
            # now, to go back to if the new one has a problem.
            (pkgs.writeShellScript "nixos-upgrade-not-pending" ''
              if ${updatePending}; then
                echo "An update is already installed and waiting for a restart."
                ${restartNotice}
                exit 1
              fi
            '')
            # After waking from sleep, wait for Wi-Fi to reconnect (up to 15
            # minutes). With no network the update is skipped until tomorrow.
            "${config.networking.networkmanager.package}/bin/nm-online -q -t 900"
          ];
          # Run in the background without slowing down the desktop. If memory
          # runs out, earlyoom picks the update to stop before your programs.
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          OOMScoreAdjust = 500;
          RuntimeDirectory = "nixos-upgrade";
        };
        # Remember which system is running, then stop if the update would
        # compile something big (see files/bin/update-check).
        preStart = ''
          readlink -f /run/current-system > "$RUNTIME_DIRECTORY/running-at-start"
          ${updateCheck}/bin/update-check ${toString config.system.autoUpgrade.flags}
        '';
        postStart = ''
          if [ "$(readlink -f /run/current-system)" != "$(cat "$RUNTIME_DIRECTORY/running-at-start")" ]; then
            # sysupdate (or sysrollback) switched systems while this update
            # ran. This update was built from the older settings, so make the
            # system you chose the one that starts next.
            echo "The running system changed during the update; keeping it for the next start."
            nix-env --profile /nix/var/nix/profiles/system --set /run/current-system
            /run/current-system/bin/switch-to-configuration boot
          elif ${updatePending}; then
            ${restartNotice}
          fi
        '';
        unitConfig.OnFailure = [ "nixos-upgrade-failed.service" ];
      };

      nixos-upgrade-failed = {
        description = "Tell the user that the automatic update failed";
        serviceConfig.Type = "oneshot";
        script = notify "Automatic update failed" "It will try again tomorrow. To see why: journalctl -u nixos-upgrade";
      };
    };
  };
}
