inputs: { config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (lib) mkOption types mkEnableOption;
  cfg = config.feaston;
in
{
    options.feaston = {
        enable = mkEnableOption ''
          Feaston event contribution planner     
        '';
        package = mkOption {
            type = types.package;
            default = inputs.self.packages.${system}.default;
            description = ''
                The package to use with the service.
            '';
        };
        domain = mkOption {
            type = types.str;
            default = "feaston.ddns.net";
            description = ''
                Domain from which the service will be exposed.
            '';
        };
        port = mkOption {
            type = types.int;
            default = 5000;
            description = ''
                Port where the service is exposed locally.
            '';
        };
        databaseURL = mkOption {
            type = types.str;
            default = "/var/feaston/db.sqlite";
            description = ''
                Location of the sqlite database.
            '';
        };
    };

    config = lib.mkIf cfg.enable {
        
        users.users.feaston = {
          isNormalUser = true;
          password = "";
          # Allow user services to run without an active user session
          linger = true;
        };

        services.nginx = {
            enable = true;
            virtualHosts = {
                "${cfg.domain}" = {
                    root = cfg.package;
                    locations."/" = {
                      tryFiles = "$uri $uri/ /index.html";
                    };
                    locations."~\.css" = {
                      extraConfig = ''add_header Content-Type text/css'';
                    };
                    locations."~\.js" = {
                      extraConfig = ''add_header Content-Type application/x-javascript'';
                    };
                    locations."/api/" = {
                      proxyPass = "http://127.0.0.1:${toString cfg.port}";
                    };
                };
            };
        };

        home-manager.users.feaston = {
          systemd.user = {
            startServices = "sd-switch";
            services."feaston" = {
              Unit = {
                Description = "Serve Feast-On web service.";
              };
              Install = {
                WantedBy = [ "multi-user.target" ];
              };
              Service = {
                ExecStart = "${cfg.package}/bin/feaston --database-url ${cfg.databaseUrl} --port ${toString cfg.port}";
                Restart = "always";
              };
            };
          };
          home.stateVersion = "24.05";
        };
    };
}
