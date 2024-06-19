inputs: { config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.services.feaston;
  defaultUser = "feaston";
  defaultGroup = "feaston";
in
{
  options = {
    services.feaston = {
      enable = lib.mkEnableOption ''
      Feaston event contribution planner     
      '';
      package = lib.mkOption {
        type = lib.types.package;
        default = if cfg.enableNginx 
          then inputs.self.packages.${system}.feaston-nginx 
          else inputs.self.packages.${system}.feaston;
        description = ''
        The package to use with the service.
        '';
      };
      domain = lib.mkOption {
        type = lib.types.str;
        description = ''
        Domain from which the service will be exposed.
        '';
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 5000;
        description = ''
        Port where the service is exposed locally.
        '';
      };
      database.url = lib.mkOption {
        type = lib.types.str;
        default = "sqlite:/var/lib/feaston/db.sqlite?mode=rwc";
        description = ''
        Location of the sqlite database.
        '';
      };
      enableTLS = lib.mkEnableOption "automatic TLS setup";
      enableNginx = lib.mkEnableOption "nginx virtualhost definitions";
      logLevel = lib.mkOption {
        type = lib.types.enum [ "error" "warn" "info" "debug" "trace" ];
        default = "error";
        description = ''
        Log level to run with.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {

    users = {
      groups.${defaultUser} = {};
      users.${defaultUser} = {
        group = defaultGroup;
        isSystemUser = true;
      };
    };

    systemd.services.feaston = {
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        User = "feaston";
        Group = "feaston";
        ExecStart = "${cfg.package}/bin/feaston --port ${toString cfg.port} --database-url ${cfg.database.url}";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    services.nginx.virtualHosts = lib.mkIf cfg.enableNginx {
      "${cfg.domain}" = {
        enableACME = cfg.enableTLS;
        forceSSL = cfg.enableTLS;
        root = "${inputs.self.packages.${system}.feaston-nginx}/www";
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
        locations."/api/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}/";
          recommendedProxySettings = true;
        };
      };
    };
  };
}
