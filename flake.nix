{
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
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

  outputs = inputs @ { self, nixpkgs, crane, fenix, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      crossSystem = "aarch64-linux";

      pkgs = import nixpkgs {
        inherit system crossSystem;
      };

      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-opUgs6ckUQCyDxcB9Wy51pqhd0MPGHUVbwRKKPGiwZU=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      commonArgs = { qemu, gcc, pkg-config, stdenv }:
      {
        src = ./.;
        strictDeps = true;

        depsBuildBuild = [ qemu gcc ];

        nativeBuildInputs = [ pkg-config stdenv.cc gcc ];

        buildInputs = [ ];

        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

        cargoExtraArgs = "--target aarch64-unknown-linux-gnu";

        HOST_CC = "${stdenv.cc.nativePrefix}cc";
        TARGET_CC = "${stdenv.cc.targetPrefix}cc";
      };

      cargoArtifactsExpression = { qemu, gcc, pkg-config, stdenv }:
      craneLib.buildDepsOnly
      {
        src = ./.;
        strictDeps = true;

        depsBuildBuild = [ qemu gcc ];

        nativeBuildInputs = [ pkg-config stdenv.cc gcc ];

        buildInputs = [ ];

        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

        cargoExtraArgs = "--target aarch64-unknown-linux-gnu";

        HOST_CC = "${stdenv.cc.nativePrefix}cc";
        TARGET_CC = "${stdenv.cc.targetPrefix}cc";
      };

      cargoArtifacts = pkgs.callPackage cargoArtifactsExpression { };

      crateExpression = { qemu, gcc, pkg-config, stdenv, sqlx-cli, brotli, gzip, tailwindcss }:
      craneLib.buildPackage
      {
        inherit cargoArtifacts;
        src = ./.;
        strictDeps = true;

        depsBuildBuild = [ qemu gcc ];

        nativeBuildInputs = [ pkg-config stdenv.cc gcc ];

        buildInputs = [ ];

        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

        cargoExtraArgs = "--target aarch64-unknown-linux-gnu";

        HOST_CC = "${stdenv.cc.nativePrefix}cc";
        TARGET_CC = "${stdenv.cc.targetPrefix}cc";

        preBuild = ''
          export DATABASE_URL=sqlite:./db.sqlite?mode=rwc
          ${sqlx-cli}/bin/sqlx database create
          mkdir -p migrations
          ${sqlx-cli}/bin/sqlx migrate run
        '';
        postInstall = ''
          cp -r www $out/
          cp -r migrations $out/
          ${tailwindcss}/bin/tailwindcss -i styles/tailwind.css --minify -o $out/www/assets/main.css
          for file in $(find $out/www -type f \( -name "*.css" -o -name "*.js" -o -name "*.html" \)); do
            ${brotli}/bin/brotli --best --keep $file
            ${gzip}/bin/gzip --best --keep $file
          done
        '';
      };

      feaston = pkgs.callPackage crateExpression { };
    in {
      checks = {
        inherit feaston;
      };

      packages.default = feaston;

      devShells.default = craneLib.devShell {

        DATABASE_URL="sqlite:./db.sqlite?mode=rwc";
        
        packages = with pkgs; [
          nginx
          sqlx-cli
          tailwindcss
          cargo-watch
          # mprocs
          # grc
          
          # Formatter
          # rustfmt
          # rustywind # CLI for organizing Tailwind CSS classes
          # nodePackages.prettier
        ];
      };
    });
}
