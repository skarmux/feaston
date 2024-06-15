{
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ 
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" 
    ];
  };

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
      # nixosModules.feaston = import ./modules/feaston/default.nix;
    };
    perSystem = { pkgs, system, ... }:
    let
      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-opUgs6ckUQCyDxcB9Wy51pqhd0MPGHUVbwRKKPGiwZU=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      commonArgs = {
        src = craneLib.cleanCargoSource ./.;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.pkg-config ];
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

      feaston = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;
        src = let
          sqlFilter = path: _type: null != builtins.match ".*sql$" path;
          sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);
        in pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = sqlOrCargo;
          name = "source";
        };
        strictDeps = true;

        nativeBuildInputs = [ pkgs.sqlx-cli ];

        preBuild = ''
          export DATABASE_URL=sqlite:./db.sqlite?mode=rwc
          sqlx database create
          sqlx migrate run
        '';

        postInstall = ''
          cp -r migrations $out/
        '';
      });
    in {
      checks = {
        inherit feaston;
      };

      packages.default = pkgs.symlinkJoin {
        name = "feaston";
        paths = [ feaston static ];
      };

      devShells.default = craneLib.devShell {

        DATABASE_URL="sqlite:./db.sqlite?mode=rwc";

        shellHook = ''
          echo "Don't forget to run 'nginx -p nginx -c nginx.conf -e error.log' once before 'mprocs'."
        '';

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
    };
  };
}
