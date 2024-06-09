{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-analyzer-src.follows = "";
      };
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { crane, fenix, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];

    flake = {
      nixosModules = rec {
        feaston = import ./modules/feaston inputs;
        default = feaston;
      };
    };

    perSystem = { pkgs, system, ... }:
    let
      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-opUgs6ckUQCyDxcB9Wy51pqhd0MPGHUVbwRKKPGiwZU=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      commonArgs = {
        src = ./.;

        strictDeps = true;

        nativeBuildInputs = [
          pkgs.pkg-config
        ];

        buildInputs = [
          pkgs.openssl
        ];
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      feaston = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;

        nativeBuildInputs = (commonArgs.nativeBuildInputs or [ ]) ++ [
          pkgs.sqlx-cli
        ];

        preBuild = ''
          export DATABASE_URL=sqlite:./db.sqlite?mode=rwc
          sqlx database create
          mkdir -p migrations
          sqlx migrate run
        '';
        
        postInstall = ''
          cp -r www $out/
          cp -r migrations $out/
          ${pkgs.tailwindcss}/bin/tailwindcss -i styles/tailwind.css --minify -o $out/www/assets/main.css

          for file in $(find $out/www -type f \( -name "*.css" -o -name "*.js" -o -name "*.html" \)); do
            ${pkgs.brotli}/bin/brotli --best --keep $file
            ${pkgs.gzip}/bin/gzip --best --keep $file
          done
        '';
      });
    in {

      packages.default = feaston;

      devShells.default = craneLib.devShell {
        
        DATABASE_URL="sqlite:./db.sqlite?mode=rwc";
        
        packages = with pkgs; [
          nginx
          sqlx-cli
          tailwindcss
          cargo-watch
          mprocs
          grc
          
          # Formatter
          rustfmt
          rustywind # CLI for organizing Tailwind CSS classes
          nodePackages.prettier
        ];
      };

      checks = {
        inherit feaston;
      };

    };
  };
}
