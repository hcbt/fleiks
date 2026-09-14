# Fleiks

Nix overlay of packages that are missing from nixpkgs, or not the build we want.

## Language

**Overlay Package**:
A package defined by this overlay, with its own upstream version and hashes.
_Avoid_: flake package, derivation, formula

**Flake Lock**:
The recorded pin of this overlay's flake inputs. Today that is only nixpkgs.
_Avoid_: flake, lockfile, pin, flake.nix

**Lock Bump**:
Advancing the Flake Lock to a newer input revision.
_Avoid_: update, upgrade, refresh
