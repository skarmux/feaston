{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (localSystem:
      let
        crossSystem = "aarch64-linux";

        pkgs = import nixpkgs {
          inherit localSystem crossSystem;
          overlays = [ (import rust-overlay) ];
        };

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.stable.latest.default.override {
          targets = [ "aarch64-unknown-linux-gnu" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        sqlFilter = path: _type: null != builtins.match ".*sql$" path;
        sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);

        src = pkgs.lib.cleanSourceWith {
          src = craneLib.path ./.; # The original, unfiltered source
          filter = sqlOrCargo;
        };

        # Note: we have to use the `callPackage` approach here so that Nix
        # can "splice" the packages in such a way that dependencies are
        # compiled for the appropriate targets. If we did not do this, we
        # would have to manually specify things like
        # `nativeBuildInputs = with pkgs.pkgsBuildHost; [ someDep ];` or
        # `buildInputs = with pkgs.pkgsHostHost; [ anotherDep ];`.
        #
        # Normally you can stick this function into its own file and pass
        # its path to `callPackage`.
        crateExpression =
          { openssl
          , libiconv
          , lib
          , pkg-config
          , qemu
          , sqlx-cli
          , stdenv
          }:
          craneLib.buildPackage {
            # src = craneLib.cleanCargoSource (craneLib.path ./.);
            src = craneLib.path ./.;
            # inherit src;
            # strictDeps = true;

            # Build-time tools which are target agnostic. build = host = target = your-machine.
            # Emulators should essentially also go `nativeBuildInputs`. But with some packaging issue,
            # currently it would cause some rebuild.
            # We put them here just for a workaround.
            # See: https://github.com/NixOS/nixpkgs/pull/146583
            depsBuildBuild = [
              # qemu
            ];

            # Dependencies which need to be build for the current platform
            # on which we are doing the cross compilation. In this case,
            # pkg-config needs to run on the build platform so that the build
            # script can find the location of openssl. Note that we don't
            # need to specify the rustToolchain here since it was already
            # overridden above.
            nativeBuildInputs = [
              pkg-config
              sqlx-cli
            ];

            # Dependencies which need to be built for the platform on which
            # the binary will run. In this case, we need to compile openssl
            # so that it can be linked with our executable.
            buildInputs = [
              # Add additional build inputs here
              openssl
            ];

            preBuild = ''
              export DATABASE_URL=sqlite:./db.sqlite3
              sqlx database create
              mkdir -p migrations
              sqlx migrate run
            '';
            
            postInstall = ''
              cp -r templates $out/
              cp -r assets $out/
              cp -r migrations $out/
            '';

            # Tell cargo about the linker and an optional emulater. So they can be used in `cargo build`
            # and `cargo run`.
            # Environment variables are in format `CARGO_TARGET_<UPPERCASE_UNDERSCORE_RUST_TRIPLE>_LINKER`.
            # They are also be set in `.cargo/config.toml` instead.
            # See: https://doc.rust-lang.org/cargo/reference/config.html#target
            CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
            # CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

            # Tell cargo which target we want to build (so it doesn't default to the build system).
            # We can either set a cargo flag explicitly with a flag or with an environment variable.
            cargoExtraArgs = "--target aarch64-unknown-linux-gnu";
            # CARGO_BUILD_TARGET = "aarch64-unknown-linux-gnu";

            # This environment variable may be necessary if any of your dependencies use a
            # build-script which invokes the `cc` crate to build some other code. The `cc` crate
            # should automatically pick up on our target-specific linker above, but this may be
            # necessary if the build script needs to compile and run some extra code on the build
            # system.
            HOST_CC = "${stdenv.cc.nativePrefix}cc";
          };

        feaston = pkgs.callPackage crateExpression { };
      in
      {
        nixosModules.default = { pkgs, config, lib, ... }: {
          options.services.feaston = {
            enable = lib.mkEnableOption ''
              Feaston event contribution planner     
            '';

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              description = ''
                The package to use with the service.
              '';
            };
          }; # options.services.feaston
          config = lib.mkIf config.service.feaston.enable {
            users.users.feaston = {
              description = "Feaston daemon user";
              isSystemUser = true;
              password = "";
              group = "feaston";

              # Whether to enable lingering for this user. If true, systemd user units
              # will start at boot, rather than starting at login and stopping at logout.
              # This is the declarative equivalent of running loginctl enable-linger for 
              # this user.
              linger = true;
            };

            users.groups."feaston" = {};

            systemd.services.feaston = {
              description = "Feaston event contribution planner";

              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                User = "feaston";
                Group = "feaston";
                Restart = "always";
                ExecStart = "${config.services.feaston.package}/bin/feaston";
                StateDirectory = "feaston";
                StateDirectoryMode = "0750";        
              };
            }; # systemd.services.feaston
          }; # config
        };

        checks = {
          inherit feaston;
        };
        # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

        packages = {
          "aarch64-linux".default = feaston;
        };

        # devShells.default = craneLib.devShell {
        #   # Additional dev-shell environment variables can be set directly
        #   DATABASE_URL="sqlite:./sqlite.db";
          
        #   # Extra inputs can be added here; cargo and rustc are provided by default.
        #   packages = with pkgs; [
        #     sqlx-cli
        #     rustywind # CLI for organizing Tailwind CSS classes
        #     tailwindcss
        #     bacon
        #     cargo-watch
        #     systemfd
        #     just
        #     rust-analyzer
        #     rustfmt
        #     tailwindcss-language-server
        #     nodePackages.vscode-langservers-extracted
        #   ];
        # };
      }
    );
}
