{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { crane, fenix, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];

    flake = {
      
    };

    nixosModules.feaston = import ./modules/feaston;
    nixosModules.default = self.nixosModules.feaston;

    perSystem = { pkgs, system, ... }:
    let
      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-opUgs6ckUQCyDxcB9Wy51pqhd0MPGHUVbwRKKPGiwZU=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      # sqlFilter = path: _type: null != builtins.match ".*sql$" path;
      # sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);

      # src = pkgs.lib.cleanSourceWith {
      #   src = craneLib.path ./.; # The original, unfiltered source
      #   filter = sqlOrCargo;
      # };

      commonArgs = {
        # inherit src;
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
          cp -r templates $out/
          cp -r assets $out/
          cp -r migrations $out/
        '';
      });
    in {

      packages.default = feaston;

      devShells.default = craneLib.devShell {
        
        DATABASE_URL="sqlite:./db.sqlite?mode=rwc";
        
        packages = with pkgs; [
          sqlx-cli
          tailwindcss
          cargo-watch
          mprocs
          
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
