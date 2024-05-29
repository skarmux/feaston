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
        services.nginx = {
            enable = true;
            virtualHosts = {
                "${cfg.domain}" = {
                    locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port}";
                };
            };
        };
        systemd.services.feaston = {
            description = "Feast On event contribution planner";

            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
                User = "feaston";
                Group = "feaston";
                Restart = "always";
                ExecStart = "${cfg.package}/bin/feaston";
                StateDirectory = "feaston";
                StateDirectoryMode = "0750";        
            };
        };
    };
    
}