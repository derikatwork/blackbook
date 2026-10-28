{
  description = "NixOS for a Lenovo 14e Chromebook (board LIARA)";

  inputs = {
    # NixOS 26.05 gets updates until 2026-12-31.
    # To move to NixOS 26.11, change "nixos-26.05" to "nixos-26.11" on the
    # next line, then run `nix flake update` (see README, section 11).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs }:
    {
      # The name "liara" is the hostname. On the laptop, apply changes with
      # `sysupdate` (modules/base.nix): it builds this with the newest
      # nixpkgs, like the automatic updates do.
      nixosConfigurations.liara = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/liara/configuration.nix
          # The copy of this repo the system is built from. Automatic updates
          # (modules/updates.nix) rebuild this same copy with newer packages.
          { local.configSource = self.outPath; }
        ];
      };
    };
}
