{
  description = "NixOS VM with GNOME on nixpkgs unstable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
  };

  outputs = {
    self,
    nixpkgs,
    nur,
    nix-flatpak,
  }: {
    nixosConfigurations.kale-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {nixpkgs.overlays = [nur.overlays.default];}
      ];
    };
  };
}
