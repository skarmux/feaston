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
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        toolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "qrWV5EuMDQSE6iiydNzO8Q09kH3SxryMLwLlzps3LY4=";
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        sqlFilter = path: _type: null != builtins.match ".*sql$" path;
        sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);

        src = pkgs.lib.cleanSourceWith {
          src = craneLib.path ./.; # The original, unfiltered source
          filter = sqlOrCargo;
        };

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
        });
      in
      {
        packages = {
          default = feaston;
        };

        nixosModules.default = { pkgs, config, lib, ... }: {
          options.services.feaston = {
            enable = lib.mkEnableOption ''
              Feaston event contribution planner     
            '';

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.default;
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

        checks = {
          inherit feaston;
        };
        # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
      }
    );
}
