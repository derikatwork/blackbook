# Boot loader and kernel.
{ config, pkgs, ... }:

let
  esp = config.boot.loader.efi.efiSysMountPoint; # "/boot"
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd-boot keeps a copy of each kernel and initrd on the 1 GiB EFI
  # partition. Keeping only 3 boot entries stops it from filling up.
  boot.loader.systemd-boot.configurationLimit = 3;

  # Show the boot menu for 2 seconds (press an arrow key to stop the countdown).
  boot.loader.timeout = 2;

  # `bootctl install` also writes the fallback loader \EFI\BOOT\BOOTX64.EFI,
  # which the firmware boots if its boot entry is ever lost. This makes sure
  # the file is still there after every rebuild.
  boot.loader.systemd-boot.extraInstallCommands = ''
    if [ ! -e "${esp}/EFI/BOOT/BOOTX64.EFI" ] && [ -e "${esp}/EFI/systemd/systemd-bootx64.efi" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "${esp}/EFI/BOOT"
      ${pkgs.coreutils}/bin/cp "${esp}/EFI/systemd/systemd-bootx64.efi" "${esp}/EFI/BOOT/BOOTX64.EFI"
    fi
  '';

  # Stoney Ridge speaker and microphone support arrived in Linux 6.19.
  # NixOS 26.05's default kernel is 6.18, so use the newest kernel instead.
  # It comes ready-built from cache.nixos.org (nothing is compiled here).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Empty /tmp on every boot.
  boot.tmp.cleanOnBoot = true;
}
