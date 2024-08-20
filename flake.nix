{
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ 
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" 
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    crane = {
      url = "github:skarmux/crane";
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
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = inputs @ { crane, fenix, flake-parts, advisory-db, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    flake = {
      nixosModules.default = import ./modules/feaston/default.nix inputs;
    };
    perSystem = { pkgs, system, ... }:
    let
      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-3jVIIf5XPnUU1CRaTyAiO0XHVbJl12MSx3eucTXCjtE=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      src = craneLib.cleanCargoSource ./.;

      commonArgs = {
        inherit src;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.pkg-config ];
      };

      databaseArgs = {
        src = let
          sqlFilter = path: _type: null != builtins.match ".*sql$" path;
          sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);
        in pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = sqlOrCargo;
          name = "source";
        };

        nativeBuildInputs = with pkgs; [ 
          sqlx-cli 
          pkg-config
        ];
  
        DATABASE_URL = "sqlite:./db.sqlite?mode=rwc";

        preBuild = ''
          sqlx database create
          sqlx migrate run
        '';
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      feaston-api = pkgs.callPackage ./feaston-api.nix {
        inherit craneLib cargoArtifacts databaseArgs;
      };

      feaston-static = pkgs.callPackage ./feaston-static.nix {};
    in {
      checks = {
        inherit feaston-api; # There are no frontend checks for now

        # feaston-clippy = craneLib.cargoClippy (commonArgs // databaseArgs // {
        #   inherit cargoArtifacts;
        #   cargoClippyExtraArgs = "--all-targets -- --deny warnings";
        # });
        #
        # feaston-doc = craneLib.cargoDoc (commonArgs // databaseArgs // {
        #   inherit cargoArtifacts;
        # });
        #
        # # Check formatting
        # feaston-fmt = craneLib.cargoFmt {
        #   inherit src;
        # };
        #
        # # Audit dependencies
        # feaston-audit = craneLib.cargoAudit {
        #   inherit src advisory-db;
        # };
        #
        # # Audit licenses
        # feaston-deny = craneLib.cargoDeny {
        #   inherit src;
        # };

        feaston-nextest = craneLib.cargoNextest (commonArgs // databaseArgs // {
          inherit cargoArtifacts;
          cargoNextestExtraArgs = "--features serve-static";
        });
      };

      packages = rec {
        feaston = pkgs.symlinkJoin {
          name = "feaston";
          paths = [
            feaston-api
            feaston-static
          ];
        };
        feaston-nginx = pkgs.symlinkJoin {
          name = "feaston";
          paths = [
            (feaston-api.override { withServeStatic = false; })
            feaston-static
          ];
        };
        default = feaston;
      };

      devShells.default = craneLib.devShell {

        DATABASE_URL="sqlite:./db.sqlite?mode=rwc";

        packages = with pkgs; [
          sqlx-cli
          tailwindcss
          cargo-watch
          mprocs
          grc # colorize output logs

          # Formatter
          rustfmt
          rustywind # reorder Tailwind CSS classes
          nodePackages.prettier # Node.js :(
        ];
      };
    };
  };
}
