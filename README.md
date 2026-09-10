# fleiks

Nix packages that are not in nixpkgs, or not the build we want. One directory per
package under `pkgs/`. The flake exports `overlays.default` and
`packages.<system>.<name>`.

```
nix run github:hcbt/fleiks#muse-code -- --version
nix run github:hcbt/fleiks#opencodex -- --version
nix run github:hcbt/fleiks#sogen -- --help
nix run github:hcbt/fleiks#utm
```

## Packages

| Attribute   | Program | Notes                                      |
| ----------- | ------- | ------------------------------------------ |
| `muse-code` | `muse`  | Meta Muse Code CLI. Unfree native binary.  |
| `opencodex` | `ocx`   | Provider proxy for Codex / Claude Code. MIT. Also installs `opencodex`. |
| `sogen`     | `analyzer` | Windows and Linux userspace emulator with GDB support. GPL-2.0-only. |
| `utm`       | `UTM`   | Virtual machines for macOS. Apache-2.0 dmg; newer than nixpkgs 4.7.5. Darwin only. |

Sogen is built from a pinned source commit with SDL3 and the Steam bridge enabled.
Steamworks headers are pinned from Valve's Proton repository and the bridge is
generated during the build. The optional Rust (Icicle) backend and Python bindings
are disabled. Windows emulation requires a separate emulation root; see the
[upstream setup guide](https://github.com/momo5502/sogen/wiki).

```
nix run github:hcbt/fleiks#sogen -- -e /path/to/root /path/to/program.exe
EMULATOR_LINUX=1 nix run github:hcbt/fleiks#sogen -- --root /path/to/root /path/to/program
```

The Steam bridge needs a running host Steam client, the guest Steam shim in your
emulation root, and the game's `SteamAppId` set on both the host and guest. See
[upstream Steam setup](https://github.com/momo5502/sogen/blob/main/docs/steam-bridge.md#running-a-real-game).

On macOS, do not run `grab-registry.bat`: that script captures a Windows host's
registry and is only needed when building a root on Windows. The Nix package
already includes the published root, so use the literal `root` path:

```sh
nix run github:hcbt/fleiks#sogen -- \
  -e root c:/test-sample.exe
```

The package fetches the published root from `sogen.dev` and maps `-e root` to
that store path. It includes `api-set.bin`, the registry hives, Windows system
DLLs, and both `steamclient.dll` and `steamclient64.dll` under `root/filesys/c/steam`.
The macOS host bridge loads Steam from its standard location. Set
`SOGEN_STEAMCLIENT` if Steam is installed elsewhere, and set `SteamAppId` to the
game's real app ID before launching it.

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

  environment.systemPackages = [
    pkgs.muse-code
    pkgs.opencodex
    pkgs.utm
  ];
  # home.packages = [ pkgs.muse-code pkgs.opencodex pkgs.utm ];
}
```

Without an overlay, take the flake package directly:

```nix
inputs.fleiks.packages.${pkgs.stdenv.hostPlatform.system}.muse-code
# or .opencodex / .utm
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
  packages = [
    pkgs.muse-code
    pkgs.opencodex
    pkgs.utm
  ];
}
```

Without the yaml overlay, pull the package from the flake output:

```nix
{ pkgs, inputs, ... }:
{
  packages = [
    inputs.fleiks.packages.${pkgs.stdenv.system}.muse-code
    inputs.fleiks.packages.${pkgs.stdenv.system}.opencodex
    inputs.fleiks.packages.${pkgs.stdenv.system}.utm
  ];
}
```
