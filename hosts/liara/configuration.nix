# The Chromebook itself: who uses it, what it is called, and which
# modules make up the system. Most settings live in ../../modules/.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base.nix
    ../../modules/boot.nix
    ../../modules/hardware.nix
    ../../modules/audio.nix
    ../../modules/network.nix
    ../../modules/desktop.nix
  ];

  # Also the flake output name (flake.nix) and the Tailscale device name.
  networking.hostName = "liara";

  local = {
    username = "derik";
    fullName = "Derik";

    # SSH *public* keys that may log in over Tailscale (never private keys).
    # Leave the list empty to keep SSH turned off. Example:
    #   sshKeys = [ "ssh-ed25519 AAAAC3Nza... derik@main-computer" ];
    sshKeys = [ ];
  };

  # The NixOS release this machine was first installed with. Leave it at
  # "26.05" even after upgrading; it is not the version you are running.
  system.stateVersion = "26.05";
}
