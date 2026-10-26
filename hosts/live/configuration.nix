# The live USB (README, sections 6 and 7): the same desktop as the installed
# Chromebook, started from the USB stick without changing the laptop, plus an
# "Install NixOS on this Chromebook" launcher entry (the `install-liara`
# command). That downloads this repo from GitHub and runs scripts/install.sh,
# so the laptop always gets the newest config, whatever the age of the USB.
#
# Built by .github/workflows/live-iso.yml, or with `nix build .#live-iso`.
{ config, lib, pkgs, modulesPath, ... }:

let
  repoUrl = "https://github.com/derikatwork/blackbook";

  installLiara = pkgs.writeShellScriptBin "install-liara" (
    builtins.replaceStrings [ "@repoUrl@" ] [ repoUrl ] (builtins.readFile ../../files/bin/install-liara)
  );
  # linux-firmware for the live USB (see hardware.firmware below). Starts from
  # the same compressed package as the installed system, from cache.nixos.org.
  liveLinuxFirmware =
    let
      full = pkgs.compressFirmwareZstd pkgs.linux-firmware;
    in
    pkgs.runCommand "${full.name}-live"
      {
        passthru.compressFirmware = false; # already compressed
        disallowedRequisites = [ full ];
      }
      ''
        cp -a ${full} $out
        chmod -R u+w $out
        cd $out/lib/firmware
        rm -r qcom nvidia mellanox mrvl/prestera netronome qed dpaa2 cxgb4 bnx2x liquidio
        # The links that pointed into those folders (Qualcomm phone GPU firmware).
        find -L . -type l -print -delete
      '';

  installEntry = pkgs.makeDesktopItem {
    name = "install-liara";
    desktopName = "Install NixOS on this Chromebook";
    comment = "Erase the internal disk and install the Chromebook system from GitHub";
    icon = "drive-harddisk";
    # --hold keeps the window open at the end, so the last message stays readable.
    exec = ''foot --hold --title="Install NixOS" --window-size-chars=90x32 install-liara'';
    categories = [ "System" ];
  };
in
{
  imports = [
    # NixOS's own installer USB: boot menu, live file system, installer tools.
    "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
    # Everything of the installed system except the boot loader, the disk
    # layout (hardware-configuration.nix) and automatic updates.
    ../../modules/base.nix
    ../../modules/hardware.nix
    ../../modules/audio.nix
    ../../modules/network.nix
    ../../modules/desktop.nix
  ];

  networking.hostName = "liara-live";
  nixpkgs.hostPlatform = "x86_64-linux";

  # The installer's user: no password, sudo without a password, logged in
  # straight into the desktop (greetd, modules/desktop.nix).
  local = {
    username = "nixos";
    fullName = "NixOS live";
  };

  # The same kernel as the installed system (modules/boot.nix). There is no
  # ZFS module for the newest kernel, and nothing here needs ZFS.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems.zfs = lib.mkForce false;

  isoImage.edition = "liara";

  # GitHub only takes release files under 2 GiB, and the firmware collection
  # is the biggest part of the image (about 835 MB, already compressed). Leave
  # out firmware for hardware that can't be in or plugged into this laptop:
  # Qualcomm phone and ARM-laptop chips, NVIDIA graphics, and server network
  # cards and switches (about 515 MB). All Wi-Fi and Bluetooth firmware stays,
  # also for USB dongles. The installed system keeps the full collection.
  # This is the list hardware.enableRedistributableFirmware adds in NixOS 26.05
  # (nixos/modules/hardware/all-firmware.nix), with the smaller linux-firmware.
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.wirelessRegulatoryDatabase = true;
  hardware.firmware = [ liveLinuxFirmware ] ++ (with pkgs; [
    ipw2200-firmware
    rtl8192su-firmware
    rt5677-firmware
    rtl8761b-firmware
    zd1211fw
    alsa-firmware
    sof-firmware
    libreelec-dvb-firmware
  ]);

  # Not useful on a USB stick that forgets everything at shutdown.
  services.tailscale.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
  services.btrfs.autoScrub.enable = lib.mkForce false;
  # install.sh installs from the flake, not from a channel, and the manual is
  # online; leaving both out keeps the image smaller.
  system.installer.channel.enable = false;
  documentation.nixos.enable = lib.mkForce false;

  # The live user has no password, so pressing Enter unlocks the lock screen.
  security.pam.services.swaylock.allowNullPassword = true;
  environment.etc."xdg/swaylock/config".source = lib.mkForce (
    pkgs.writeText "swaylock-config" (
      builtins.replaceStrings [ "ignore-empty-password\n" ] [ "" ] (builtins.readFile ../../files/swaylock/config)
    )
  );

  environment.systemPackages = [ installLiara installEntry ];

  system.stateVersion = "26.05";
}
