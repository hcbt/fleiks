# fleiks

Nix packages that are not in nixpkgs, or not the build we want. One directory per
package under `pkgs/`. The flake exports `overlays.default` and
`packages.<system>.<name>`.

```
nix run github:hcbt/fleiks#muse-code -- --version
```

## Packages

| Attribute   | Program | Notes                                      |
| ----------- | ------- | ------------------------------------------ |
| `muse-code` | `muse`  | Meta Muse Code CLI. Unfree native binary.  |

## Flake

Pin the input and follow your nixpkgs:

```nix
{
  inputs.fleiks = {
    url = "github:hcbt/fleiks";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Apply the overlay so the packages show up on `pkgs`. Unfree packages need
`allowUnfree`.

```nix
{
  nixpkgs = {
    overlays = [ inputs.fleiks.overlays.default ];
    config.allowUnfree = true;
  };

  environment.systemPackages = [ pkgs.muse-code ];
  # home.packages = [ pkgs.muse-code ];
}
```

Without an overlay, take the flake package directly:

```nix
inputs.fleiks.packages.${pkgs.stdenv.hostPlatform.system}.muse-code
```

## devenv

Add the input (this writes the url and the nixpkgs follow):

```
devenv inputs add fleiks github:hcbt/fleiks --follows nixpkgs
```

Then set the overlay and allow unfree in `devenv.yaml`. `overlays: [default]`
is not written by `inputs add`; add it by hand.

```yaml
nixpkgs:
  allow_unfree: true

inputs:
  fleiks:
    url: github:hcbt/fleiks
    inputs:
      nixpkgs:
        follows: nixpkgs
    overlays:
      - default
```

```nix
{ pkgs, ... }:
{
  packages = [ pkgs.muse-code ];
}
```

Without the yaml overlay, pull the package from the flake output:

```nix
{ pkgs, inputs, ... }:
{
  packages = [
    inputs.fleiks.packages.${pkgs.stdenv.system}.muse-code
  ];
}
```
