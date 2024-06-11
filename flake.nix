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

  outputs = inputs @ { nixpkgs, crane, fenix, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        crossSystem = "aarch64-linux";
      };

      toolchain = fenix.packages.${system}.fromToolchainFile {
        file = ./rust-toolchain.toml;
        sha256 = "sha256-opUgs6ckUQCyDxcB9Wy51pqhd0MPGHUVbwRKKPGiwZU=";
      };

      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

      src = ./.;

      cargoArtifactsExpression = { qemu, gcc, pkg-config, stdenv }:
      craneLib.buildDepsOnly
      {
        inherit src;
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
        inherit src cargoArtifacts;
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
