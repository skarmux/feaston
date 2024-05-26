flake: { config, lib, pkgs, ... }:
let
  cfg = config.services.feaston;
in
{
  options.services.feaston = {
    enable = lib.mkEnableOption ''
      Feaston event contribution planner     
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = flake.packages.${pkgs.system}.default;
      description = ''
        The package to use with the service.
      '';
    };
  };

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
}
