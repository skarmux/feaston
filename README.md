![example branch parameter](https://github.com/skarmux/feaston/actions/workflows/build.yml/badge.svg?branch=main)
[![built with nix](https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a)](https://builtwithnix.org)

# Install with Flakes

´´´nix
{
  services.feaston = {
    enable = true;
    domain = "feaston.skarmux.tech";
    port = 3000;
    enableNginx = true;
    enableTLS = true;
  };
}
´´´

