{ craneLib
, lib
, cargoArtifacts
, databaseArgs
, withServeStatic ? true
}:
craneLib.buildPackage {
  inherit cargoArtifacts;
  inherit (databaseArgs) src nativeBuildInputs DATABASE_URL preBuild;
  
  strictDeps = true;

  postInstall = ''
    cp -r migrations $out/
  '';

  cargoExtraArgs = (lib.optionalString withServeStatic "--features serve-static");
}

