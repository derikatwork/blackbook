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
      # The name "liara" is the hostname. Build or switch with:
      #   nixos-rebuild switch --sudo --flake ~/nixos-config#liara
      nixosConfigurations.liara = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/liara/configuration.nix ];
      };
    };
}
