# Common config used by the installer and Blackbook
# Based on Nixbook (https://github.com/mkellyxp/nixbook), with the desktop
# environment swapped for a BunsenLabs-style Openbox session (see desktop.nix)
{ pkgs, lib, ... }:

{
  imports = [
    ./chromebook.nix
    ./desktop.nix
  ];

  zramSwap.enable = true;
  zramSwap.memoryPercent = 100;

  # Plymouth boot splash screen - hides boot text for cleaner startup
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_level=3"
  ];

  # GRUB bootloader settings for silent boot (hides early kernel messages)
  boot.loader.grub.gfxpayloadBios = "keep";

  hardware.bluetooth.enable = true;

  # Enable Printing
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Common Packages
  environment.systemPackages = with pkgs; [
    git
    firefox        # web browser
    thunderbird    # email client
    libnotify
    gawk
    sudo
    galculator
    system-config-printer
  ];

  fonts = {
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fontDir.enable = true;
  };
}

## NOTES ##
# To enable auto login for user, add this to your /etc/nixos/configuration.nix
#
# services.displayManager.autoLogin = {
#   enable = true;
#   user = "user";   #make "user" whatever your username is
# }
