{ config, lib, pkgs, ... }:
{
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
}
