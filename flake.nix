{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
  flake-utils.lib.eachDefaultSystem
    (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          # config.allowUnfree = true;
        };

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        buildInputs = with pkgs; [ ]; # compile time & runtime (ex: openssl, sqlite)
        nativeBuildInputs = with pkgs; [ rustToolchain pkg-config ]; # compile time

        commonArgs = {
          inherit src buildInputs nativeBuildInputs;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        bin = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });

        dockerImage = pkgs.dockerTools.buildImage {
          name = "template";
          tag = "latest";
          copyToRoot = [ bin ];
          config = {
            Cmd = [ "${bin}/bin/template" ];
          };
        };
      in
      {
        packages = {
          inherit bin dockerImage;
          default = bin;
        };

        devShells.default = pkgs.mkShell {
          # inherit buildInputs nativeBuildInputs;
          inputsFrom = [ bin ];
          buildInputs = with pkgs; [
            sqlx-cli
            rustywind # CLI for organizing Tailwind CSS classes
            tailwindcss
            bacon
            cargo-watch
            systemfd
            just
            rust-analyzer
            rustfmt
            tailwindcss-language-server
            nodePackages.vscode-langservers-extracted
          ];
        };
      }
    );
}
