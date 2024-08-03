[![example workflow](https://github.com/skarmux/feaston/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/skarmux/feaston/actions/workflows/build.yml)
[![example workflow](https://github.com/skarmux/feaston/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/skarmux/feaston/actions/workflows/check.yml)
[![built with nix](https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a)](https://builtwithnix.org)

# Install with Nix Flakes

```nix
# flake.nix
{
    inputs = {
        nixpkgs.url = "github:nix-community/nixpkgs/nixos-unstable";
        feaston.url = "github:skarmux/feaston";
    };

    outputs = inputs @ { nixpkgs, feaston, ... }: {
        nixosConfigurations = {
            "my-system" = lib.nixosSystem {
                specialArgs = { inherit inputs; };
                modules = [
                    feaston.nixosModules.default
                    ./configuration.nix
                ];
            };
        }; 
    };
}
```

```nix
# configuration.nix
{
  # ...

  services.feaston = {
    enable = true;
    domain = "feaston.example.com";
    port = 3000;
    enableNginx = true;
    enableTLS = true;
  };
}
```

