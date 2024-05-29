{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types mkEnableOption;
  cfg = config.feaston;
in
{
    options.feaston = {
        domain = mkOption {
        type = types.str;
        description = ''
            Domain from which the service will be exposed.
        '';
        };
    };

    config = lib.mkIf cfg.enable {
        services.nginx = {
            enable = true;
            virtualHosts = {
                cfg.domain = {
                    locations."/".proxyPass = "http://127.0.0.1:5000";
                };
            };
        };
    };
}