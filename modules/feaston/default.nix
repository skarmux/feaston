inputs: { config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.services.feaston;
  defaultUser = "feaston";
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
            then inputs.self.packages.${system}.feaston-api 
            else inputs.self.packages.${system}.feaston-all;
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
          default = "/var/feaston/db.sqlite?mode=rwc";
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

      systemd.services.feaston = {
        wantedBy = [ "multi-user.target" ];
        environment.RUST_LOG = cfg.logLevel;
        serviceConfig = {
          User = defaultUser;
          Group = defaultUser;
          ExecStart = "${cfg.package}/bin/feaston --database-url ${cfg.databaseURL} --port ${toString cfg.port}";

            # hardening
            RemoveIPC = true;
            CapabilityBoundingSet = [ "" ];
            DynamicUser = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            ProtectClock = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            SystemCallArchitectures = "native";
            MemoryDenyWriteExecute = true;
            RestrictNamespaces = true;
            RestrictSUIDSGID = true;
            ProtectHostname = true;
            LockPersonality = true;
            ProtectKernelTunables = true;
            RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
            RestrictRealtime = true;
            ProtectSystem = "strict";
            ProtectProc = "invisible";
            ProcSubset = "pid";
            ProtectHome = true;
            PrivateUsers = true;
            PrivateTmp = true;
            SystemCallFilter = [ "@system-service" "~ @privileged @resources" ];
            UMask = "0077";
          };
        };

        services.nginx.virtualHosts = lib.mkIf cfg.enableNginx {
          "${cfg.domain}" = {
            enableACME = cfg.enableTLS;
            forceSSL = cfg.enableTLS;
            root = "${inputs.self.packages.${system}.static}/www";
            locations."/" = {
              tryFiles = "$uri $uri/ /index.html";
            };
            locations."/api/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.port}";
              recommendedProxySettings = true;
            };
          };
        };
      };
    }
