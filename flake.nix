{
  description = "hcbt package flakes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      overlays.default =
        final: _prev:
        lib.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ./pkgs;
        };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs)
            liqoctl
            mflux
            muse-code
            opencodex
            sogen
            utm
            xirp
            ;
        }
      );

      # nix run only starts meta.mainProgram, and attr paths split on `.`,
      # so the binary mflux-generate-qwen-2.1 is this app.
      apps.aarch64-darwin.mflux-generate-qwen-21 = {
        type = "app";
        program = "${self.packages.aarch64-darwin.mflux}/bin/mflux-generate-qwen-2.1";
      };
    };
}
