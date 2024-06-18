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
    inherit (pkgs) lib;
      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-Ngiz76YP4HTY75GGdH2P+APE/DEIx2R/Dn+BwwOyzZU";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      withServeStatic = true;
      
      src = craneLib.cleanCargoSource ./.;

      commonArgs = {
        inherit src;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.pkg-config ];
        cargoExtraArgs =
          (lib.optionalString withServeStatic "--features serve-static");
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      static = pkgs.callPackage pkgs.stdenv.mkDerivation {
        pname = "feaston-www";
        version = "1.0.0";
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type: pkgs.lib.any (suffix: pkgs.lib.hasSuffix suffix (baseNameOf path)) [
            ".js" ".html" ".css" ".webp" ".ico" ".json"
          ] || type == "directory";
          name = "source";
        };
        buildInputs = with pkgs; [ tailwindcss brotli gzip ];
        buildPhase = ''
          tailwindcss -i styles/tailwind.css --minify -o www/assets/main.css
          for file in $(find www -type f \( -name "*.css" -o -name "*.js" -o -name "*.html" \)); do
            brotli --best --keep $file
            gzip --best --keep $file
          done
        '';
        installPhase = ''
          mkdir -p $out/www
          cp -r www/** $out/www
        '';
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
        nativeBuildInputs = [ pkgs.sqlx-cli ];
        DATABASE_URL = "sqlite:./db.sqlite?mode=rwc";
        preBuild = ''
          sqlx database create
          sqlx migrate run
        '';
        postInstall = ''
          cp -r migrations $out/
        '';
      };

      feaston = craneLib.buildPackage (commonArgs // databaseArgs // {
        inherit cargoArtifacts;
      });
    in {
      checks = {
        inherit feaston;

        feaston-clippy = craneLib.cargoClippy (commonArgs // databaseArgs // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-targets -- --deny warnings";
        });

        feaston-doc = craneLib.cargoDoc (commonArgs // databaseArgs // {
          inherit cargoArtifacts;
        });

        # Check formatting
        feaston-fmt = craneLib.cargoFmt {
          inherit src;
        };

        # Audit dependencies
        feaston-audit = craneLib.cargoAudit {
          inherit src advisory-db;
        };

        # Audit licenses
        feaston-deny = craneLib.cargoDeny {
          inherit src;
        };

        feaston-nextest = craneLib.cargoNextest (commonArgs // databaseArgs // {
          inherit cargoArtifacts;
          # craneLib.cargoNextest places cargoExtraArgs between `cargo` and `nextest`
          # but it should be placed after both: `cargo nextest run --features <FEATURES>`
          cargoExtraArgs = "";
          checkPhaseCargoCommand = "cargo nextest run --profile release --features serve-static";
        });
      };

      packages.default = pkgs.symlinkJoin {
        name = "feaston";
        paths = [ feaston static ];
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
