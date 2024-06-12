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
    # flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, crane, fenix, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (localSystem:
    let
      pkgs = import nixpkgs {
        inherit localSystem;
        crossSystem = "aarch64-linux";
      };

      toolchain = fenix.packages.${localSystem}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-opUgs6ckUQCyDxcB9Wy51pqhd0MPGHUVbwRKKPGiwZU=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      cargoArtifactsExpression = { qemu, gcc, pkg-config, stdenv }:
      craneLib.buildDepsOnly
      {
        src = craneLib.cleanCargoSource ./.;
        strictDeps = true;

        depsBuildBuild = [ qemu gcc ];

        nativeBuildInputs = [ pkg-config stdenv.cc gcc ];

        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

        cargoExtraArgs = "--target aarch64-unknown-linux-gnu";

        HOST_CC = "${stdenv.cc.nativePrefix}cc";
        TARGET_CC = "${stdenv.cc.targetPrefix}cc";
      };

      cargoArtifacts = pkgs.callPackage cargoArtifactsExpression { };

      staticAssets = pkgs.callPackage pkgs.stdenv.mkDerivation {
        pname = "feaston-www";
        version = "1.0.0";
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type: pkgs.lib.any (suffix: pkgs.lib.hasSuffix suffix (baseNameOf path)) [
            ".js" ".html" ".css" ".webp" ".ico" ".json"
          ] || type == "directory";
          name = "source";
        };
        buildPhase = ''
          ${pkgs.tailwindcss}/bin/tailwindcss -i styles/tailwind.css --minify -o www/assets/main.css
          for file in $(find www -type f \( -name "*.css" -o -name "*.js" -o -name "*.html" \)); do
            ${pkgs.brotli}/bin/brotli --best --keep $file
            ${pkgs.gzip}/bin/gzip --best --keep $file
          done
        '';
        installPhase = ''
          mkdir -p $out/www
          cp -r www/** $out/www
        '';
      };

      crateExpression = { qemu, gcc, pkg-config, stdenv, sqlx-cli }:
      craneLib.buildPackage
      {
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

        depsBuildBuild = [ qemu gcc ];

        nativeBuildInputs = [ pkg-config stdenv.cc gcc ];

        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

        cargoExtraArgs = "--target aarch64-unknown-linux-gnu";

        HOST_CC = "${stdenv.cc.nativePrefix}cc";
        TARGET_CC = "${stdenv.cc.targetPrefix}cc";

        preBuild = ''
          export DATABASE_URL=sqlite:./db.sqlite?mode=rwc
          ${sqlx-cli}/bin/sqlx database create
          #mkdir -p migrations
          ${sqlx-cli}/bin/sqlx migrate run
        '';

        postInstall = ''
          cp -r migrations $out/
        '';
      };

      feaston = pkgs.callPackage crateExpression { };
    in {
      checks = {
        inherit feaston;
      };

      packages.default = pkgs.symlinkJoin {
        name = "feaston";
        paths = [ feaston staticAssets ];
      };

      devShells.default = nixpkgs.legacyPackages."x86_64-linux".mkShell {

        DATABASE_URL="sqlite:./db.sqlite?mode=rwc";

        shellHook = ''
          echo "Don't forget to run 'nginx -p nginx -c nginx.conf -e error.log' once before 'mprocs'."
        '';

        packages = with nixpkgs.legacyPackages."x86_64-linux"; [
          nginx
          sqlx-cli
          tailwindcss
          cargo-watch
          mprocs
          grc

          # Would be provided by craneLib.devShell if it werent broken for
          # cross compilation setup
          cargo
          rustc
          
          # Formatter
          rustfmt
          rustywind # CLI for organizing Tailwind CSS classes
          nodePackages.prettier
        ];
      };
    });
}
