{
  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
    flake-utils.follows = "cargo2nix/flake-utils";
    nixpkgs.follows = "cargo2nix/nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, cargo2nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [cargo2nix.overlays.default];
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;
        };
      in rec
      {
        packages = {
          # Build the actual crate itself, reusing the dependency
          # artifacts from above.
          feaston = (rustPkgs.workspace.feaston {
            buildInputs = [
              pkgs.sqlx-cli
            ];
            buildPhase = ''
              cp -r templates $out/
              cp -r assets $out/
              cp -r migrations $out/
              export DATABASE_URL=sqlite:./db.sqlite3
              sqlx database create
              sqlx migrate run
              runHook preBuild
              runHook overrideCargoManifest
              runHook setBuildEnv
              runHook runCargo
              runHook postBuild
            '';
          });
          default = packages.feaston;
        };

        # devShells.default = craneLib.devShell {
        #   # Inherit inputs from checks.
        #   checks = self.checks.${system};

        #   # Additional dev-shell environment variables can be set directly
        #   # PROJECT_ID = "voltaic-layout-417220";
        #   DATABASE_URL="sqlite:./sqlite.db";
          
        #   # Extra inputs can be added here; cargo and rustc are provided by default.
        #   packages = with pkgs; [
        #     sqlx-cli
        #     rustywind # CLI for organizing Tailwind CSS classes
        #     tailwindcss
        #     bacon
        #     cargo-watch
        #     systemfd
        #     just
        #     rust-analyzer
        #     rustfmt
        #     tailwindcss-language-server
        #     nodePackages.vscode-langservers-extracted
        #   ];
        # };
      }
    );
}
