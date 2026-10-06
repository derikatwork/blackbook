# Disks and kernel modules for the Lenovo 14e Chromebook (LIARA).
#
# Written by hand ahead of time instead of by `nixos-generate-config`.
# Everything is mounted by label, and scripts/install.sh creates exactly
# these labels. During the install, install.sh compares the module lists
# below with what `nixos-generate-config` detects on the real hardware and
# stops if anything is missing here.
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    # USB controllers and USB storage (keyboard and USB sticks in early boot).
    "xhci_pci"
    "ehci_pci"
    "ohci_pci"
    "usb_storage"
    "uas"
    "sd_mod"
    "usbhid"
    # eMMC. On Stoney Ridge Chromebooks the eMMC controller is an ACPI
    # device (sdhci_acpi); sdhci_pci covers PCI-attached SD/MMC readers.
    "sdhci_acpi"
    "sdhci_pci"
    "mmc_block"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # One btrfs filesystem with four subvolumes (see scripts/install.sh).
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd:1" "noatime" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:1" "noatime" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd:1" "noatime" ];
    # Mount early so logs from the start of boot are kept.
    neededForBoot = true;
  };

  # The EFI system partition. umask=0077 keeps it readable by root only.
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # No swap partition; compressed swap in RAM (zram) is set up in base.nix.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
