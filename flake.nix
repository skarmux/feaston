{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # nixos-generators = {
    #   url = "github:nix-community/nixos-generators";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, fenix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
          config.allowUnfree = true;
        };

        inherit (pkgs) lib;

        # rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        # craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        craneLib = crane.lib.${system};
        # src = craneLib.cleanCargoSource (craneLib.path ./.);

        # sqlFilter = path: _type: null != builtins.match ".*sql$" path;
        # sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);

        src = lib.cleanSourceWith {
          src = craneLib.path ./.; # The original, unfiltered source
          filter = path: type:
            (lib.hasSuffix "\.html" path) ||
            (lib.hasSuffix "\.sql" path) ||
            (lib.hasSuffix "\.css" path) ||
            (lib.hasSuffix "/assets/" path) ||
            (lib.hasSuffix "/templates/" path) ||
            # Default filter from crane (allow .rs files)
            (craneLib.filterCargoSources path type)
          ;
        };

        # buildInputs = with pkgs; [ ]; # compile time & runtime (ex: openssl, sqlite)
        # nativeBuildInputs = with pkgs; [ rustToolchain pkg-config ]; # compile time

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          strictDeps = true;
          nativeBuildInputs = [
            pkgs.pkg-config
          ];
          buildInputs = [
            pkgs.openssl
          ];
        };

        craneLibLLvmTools = craneLib.overrideToolchain
          (fenix.packages.${system}.complete.withComponents [
            "cargo"
            "llvm-tools"
            "rustc"
          ]);

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        feaston = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;

          nativeBuildInputs = (commonArgs.nativeBuildInputs or []) ++ [
            pkgs.sqlx-cli
          ];

          preBuild = ''
            export DATABASE_URL=postgresql://root:AURA53Lucario4130@192.168.178.22:2665/ibringdb
            sqlx database create
            sqlx migrate run
          '';
        });
      in
      {
        checks = {
          inherit feaston;
        };

        packages = {
          default = feaston;
          inherit feaston;

        # google-cloud = nixos-generators.nixosGenerate {
        #   system = system;
        #   modules = [
        #     ./configuration.nix
        #   ];
        #   format = "gce";
        # };
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Additional dev-shell environment variables can be set directly
          # PROJECT_ID = "voltaic-layout-417220";
          # BUCKET_NAME = "feaston-bucket";
          
          # Extra inputs can be added here; cargo and rustc are provided by default.
          packages = with pkgs; [
            # terraform
            # google-cloud-sdk
            # nixops_unstable
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
