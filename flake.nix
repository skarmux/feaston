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
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, crane, fenix, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];

    flake = {
      nixosModules.default = { pkgs, config, lib, ... }:
      let
        cfg = config.services.feaston;
      in {
        options.services.feaston = {
          enable = lib.mkEnableOption ''
            Feaston event contribution planner     
          '';
        }; # options.services.feaston

        config = lib.mkIf cfg.enable {

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
        };
      };
    };

    perSystem = { pkgs, config, system, ... }:
    let
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
    in {

      packages.default =
        let
          generateSystemd = type: name: config:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [{ systemd."${type}s".${name} = config; }];
            }).config.systemd.units."${name}.${type}".text;

          mkService = generateSystemd "service";

          service = pkgs.writeTextFile {
            name = "feaston.service";
            text = mkService "feaston" {
              unitConfig.WantedBy = [ "multi-user.target" ];
              path = [ feaston ];
              script = "feaston";
            };
          };
        in 
        pkgs.writeShellScriptBin "activate" ''
          mkdir -p $HOME/.config/systemd/user
          rm $HOME/.config/systemd/user/feaston.service
          ln -s ${service} $HOME/.config/systemd/user/feaston.service
          systemctl --user daemon-reload
          systemctl --user restart feaston
        '';

      devShells.default = craneLib.devShell {
        
        DATABASE_URL="sqlite:./sqlite.db";
        
        packages = with pkgs; [
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

      checks = {
        inherit feaston;
      };

    }; # perSystem
  }; # outputs
}
