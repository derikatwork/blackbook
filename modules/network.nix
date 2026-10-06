# Wi-Fi (NetworkManager), Tailscale, the firewall, and optional SSH.
{ config, lib, pkgs, ... }:

let
  cfg = config.local;
  sshEnabled = cfg.sshKeys != [ ];
in
{
  # Wi-Fi is managed by NetworkManager; the tray icon is nm-applet (started
  # from the labwc autostart, see modules/desktop.nix).
  #
  # Wi-Fi passwords: members of the "networkmanager" group may change
  # system connections, so nm-applet saves new passwords system-wide in
  # /etc/NetworkManager/system-connections/ (readable by root only). They
  # work after a reboot with auto-login and need no keyring.
  networking.networkmanager.enable = true;
  environment.systemPackages = [ pkgs.networkmanagerapplet ];

  # ModemManager is for cellular modems, which this laptop does not have.
  # NetworkManager turns it on by default; switching it off saves memory.
  networking.modemmanager.enable = false;

  # Tailscale. After installing, run `sudo tailscale up` once and log in.
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP port for direct connections between devices
  };

  networking.firewall = {
    enable = true;
    # The Tailscale module only loosens this when routing features are on.
    # "loose" is what Tailscale recommends; it keeps the anti-spoofing check
    # but still allows traffic that arrives through the tailnet (needed for
    # exit nodes and subnet routes).
    checkReversePath = "loose";
  };

  # ---- SSH, only if a public key is set in configuration.nix --------------
  services.openssh = lib.mkIf sshEnabled {
    enable = true;
    openFirewall = false; # port 22 is opened on tailscale0 only, below
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf sshEnabled [ 22 ];

  # Lets `nixos-rebuild --target-host` copy a system built on the main
  # computer to this one (those builds are not signed by cache.nixos.org).
  nix.settings.trusted-users = lib.mkIf sshEnabled [ "root" cfg.username ];
}
