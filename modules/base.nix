# Basics: Nix settings and cleanup, memory, language and time, the user
# account, the shell, and command-line tools.
{ config, lib, pkgs, ... }:

let
  cfg = config.local;
  flakeRef = "~/nixos-config#${config.networking.hostName}";
in
{
  # Small set of per-machine settings, filled in by hosts/<hostname>/configuration.nix.
  options.local = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Login name of the one normal user.";
    };
    fullName = lib.mkOption {
      type = lib.types.str;
      description = "The user's full name.";
    };
    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys allowed to log in over Tailscale. Empty means SSH is off.";
    };
  };

  config = {
    # ---- Nix ----------------------------------------------------------------
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # The Chromebook has 2 slow cores and 4 GB of RAM: one build at a time.
      max-jobs = 1;
      cores = 2;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Skip the NixOS manual (it is online); keep normal man pages.
    documentation.nixos.enable = false;

    # Keep the system journal to about 100 MB.
    services.journald.extraConfig = ''
      SystemMaxUse=100M
    '';

    # Tell the eMMC which blocks are free (weekly), and check btrfs for
    # damage once a month. One scrub of "/" covers all four subvolumes.
    services.fstrim.enable = true;
    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ];
    };

    # ---- Memory -------------------------------------------------------------
    # Compressed swap in RAM instead of a swap partition.
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    # zram is much faster than disk swap, so let the kernel use it earlier.
    # 180 is the value Fedora and Pop!_OS use with zram (the kernel allows
    # 0-200; the default of 60 assumes slow disk swap). page-cluster 0 turns
    # off swap read-ahead, which only helps on real disks.
    boot.kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };

    # Kill the biggest program before the whole system freezes when memory
    # runs out, and show a desktop notification when it does.
    services.earlyoom = {
      enable = true;
      enableNotifications = true;
    };

    # ---- Language, time, keyboard -------------------------------------------
    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";
    services.xserver.xkb.layout = "us";

    # ---- The user -----------------------------------------------------------
    users.users.${cfg.username} = {
      isNormalUser = true;
      uid = 1000;
      description = cfg.fullName;
      # wheel: may use sudo. networkmanager: may change Wi-Fi settings and
      # save Wi-Fi passwords for the whole system. No other groups are
      # needed: brightnessctl goes through logind, PipeWire uses rtkit, and
      # `keyd monitor` is run with sudo.
      extraGroups = [ "wheel" "networkmanager" ];
      openssh.authorizedKeys.keys = cfg.sshKeys;
    };

    # ---- Shell and editor ---------------------------------------------------
    programs.bash.completion.enable = true;

    programs.nano = {
      enable = true;
      syntaxHighlight = true;
      nanorc = builtins.readFile ../files/nanorc;
    };
    environment.variables.EDITOR = "nano";

    environment.shellAliases = {
      # Get the newest config from GitHub and switch to it. The build runs
      # as you; only the final "activate" step uses sudo.
      sysupdate = "git -C ~/nixos-config pull && nixos-rebuild switch --sudo --flake ${flakeRef}";
      # Delete old generations, free the disk space, and remove their boot entries.
      sysclean = "nix-collect-garbage -d && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      # Go back to the previous generation.
      sysrollback = "nixos-rebuild switch --rollback --sudo --flake ${flakeRef}";
    };

    # ---- Command-line tools -------------------------------------------------
    environment.systemPackages = with pkgs; [
      git
      curl
      wget
      htop
      unzip
      zip
      file
      tree
      rsync
      man-pages
      pciutils # lspci
      usbutils # lsusb
      alsa-utils # aplay, amixer
      libva-utils # vainfo
      wev # shows key names and events
      compsize # real disk use of btrfs-compressed files
    ];
  };
}
