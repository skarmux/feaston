{
  description = "feaston";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    naersk.url = "github:nix-community/naersk";

    # fenix = {
    #   url = "github:nix-community/fenix";
    #   inputs = {
    #     nixpkgs.follows = "nixpkgs";
    #     rust-analyzer-src.follows = "";
    #   };
    # };

    devshell.url = "github:numtide/devshell/main";

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, naersk, fenix, devshell, rust-overlay, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import rust-overlay)
            devshell.overlays.default
            naersk.overlay
          ];
        };

        toolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        naersk' = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        naerskBuildPackage = target: args:
          naersk'.buildPackage (
            args // {
              CARGO_BUILD_TARGET = target; 
            }
          );

        sqlx-db = pkgs.runCommand "sqlx-db-prepare"
          {
            nativeBuildInputs = [ pkgs.sqlx-cli ];
          } ''
          mkdir $out
          export DATABASE_URL=sqlite:$out/db.sqlite3
          sqlx database create
          sqlx migrate run --source ./migrations
        '';
      in rec
      {
        # For `nix build .#x86_64-unknown-linux-musl`:
        packages.x86_64-unknown-linux-gnu = naerskBuildPackage "x86_64-unknown-linux-gnu" {
          src = ./.;
          doCheck = true;
          CARGO_BUILD_INCREMENTAL = "false";
          RUST_BACKTRACE = "full";
          copyLibs = false;
          overrideMain = old: {
            linkDb = ''
              export DATABASE_URL=sqlite:${sqlx-db}/db.sqlite3
            '';
            preBuildPhases = [ "linkDb" ] ++ (old.preBuildPhases or [ ]);
          };
        };

        defaultPackage = packages.x86_64-unknown-linux-gnu;

        devShell = pkgs.devshell.mkShell (
          {
            # inputsFrom = with packages; [ x86_64-unknown-linux-musl ];
            name = "feaston";
            motd = ''
              Welcome to the feaston dev shell.

              Commands available:
              - work: open development environment in zellij tab
              - twatch: automatically rebuild tailwind main.css
            '';
            env = [
              {
                name = "CARGO_BUILD_TARGET ";
                value = "x86_64-unknown-linux-gnu";
              }
            ];
            commands = [
              {
                name = "work";
                help = "open development environment in new zellij tab";
                category = "development";
                command = "zellij action new-tab --cwd . --name feaston --layout zellij_layout.kdl";
              }
              {
                name = "twatch";
                help = "automatically rebuild tailwind main.css";
                category = "development";
                command = "tailwindcss -i styles/tailwind.css -o assets/main.css --watch";
              }
            ];
            packages = with pkgs; [
              rustc
              cargo
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
          }
        );
      }
    );
}
