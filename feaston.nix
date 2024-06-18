{ craneLib
, pkgs
, lib
, cargoArtifacts
, withServeStatic ? true
}:

craneLib.buildPackage {
  inherit cargoArtifacts;
  src = let
    sqlFilter = path: _type: null != builtins.match ".*sql$" path;
    sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSources path type);
  in pkgs.lib.cleanSourceWith {
    src = ./.;
    filter = sqlOrCargo;
    name = "source";
  };

  strictDeps = true;

  nativeBuildInputs = with pkgs; [ 
    sqlx-cli 
    pkg-config
  ];

  cargoExtraArgs = (lib.optionalString withServeStatic "--features serve-static");

  DATABASE_URL = "sqlite:./db.sqlite?mode=rwc";

  preBuild = ''
    sqlx database create
    sqlx migrate run
  '';

  postInstall = ''
    cp -r migrations $out/
  '';
}

