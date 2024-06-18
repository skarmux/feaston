{ pkgs }:
pkgs.stdenv.mkDerivation {

  pname = "feaston-static";
  version = "1.0.0";
  
  src = pkgs.lib.cleanSourceWith {
    src = ./.;
    filter = path: type: pkgs.lib.any (suffix: pkgs.lib.hasSuffix suffix (baseNameOf path)) [
      ".js" ".html" ".css" ".webp" ".ico" ".json"
    ] || type == "directory";
    name = "source";
  };
  
  buildInputs = with pkgs; [
    tailwindcss 
    brotli 
    gzip
  ];
  
  buildPhase = ''
    tailwindcss -i styles/tailwind.css --minify -o www/assets/main.css
    for file in $(find www -type f \( -name "*.css" -o -name "*.js" -o -name "*.html" \)); do
    brotli --best --keep $file
    gzip --best --keep $file
    done
  '';
  
  installPhase = ''
    mkdir -p $out/www
    cp -r www/** $out/www
  '';
}
