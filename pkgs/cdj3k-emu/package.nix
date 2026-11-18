{
  lib,
  undmg,
  makeWrapper,
  writeShellScript,
  fetchurl,
  stdenvNoCC,
}:

# Not built from source: the release .app carries a patched QEMU built by
# qemu/build.sh, a Linux 6.6 kernel plus out-of-tree modules built in Docker,
# and a dylib graph staged beside the app so it runs without Homebrew.
# Repackage the upstream universal dmg instead, like vibe-desktop.
# Bump: take version from https://github.com/nsaintot/cdj3k-emu/releases,
# then prefetch
#   https://github.com/nsaintot/cdj3k-emu/releases/download/v${version}/CDJ3K-Emulator-${version}-macos-universal.dmg
#
# Sparkle is embedded and the bundle is Developer ID-signed and notarized;
# leave it untouched so the signature stays valid. The updater cannot replace
# a Nix store bundle: update through Nix.
let
  version = "0.4.1";

  # The firmware wizard copies Contents/Resources/Image with fs::copy, which
  # preserves the source mode, then reopens the copy for writing to fsync it.
  # Store files are 0444, so that reopen fails with EACCES and the install
  # aborts after the eMMC is built. Stage a writable copy of Resources in the
  # user's cache and point the app at it with CDJ3K_RESOURCES, which its
  # bundled::resources() checks first. The bundle itself stays untouched.
  stageResources = writeShellScript "cdj3k-emu-stage-resources" ''
    src=$1
    cache="''${XDG_CACHE_HOME:-$HOME/Library/Caches}/cdj3k-emu/resources-${version}"

    if [ ! -d "$cache" ]; then
      tmp="$cache.tmp.$$"
      rm -rf "$tmp"
      mkdir -p "$tmp"
      if cp -R "$src/." "$tmp/" && chmod -R u+w "$tmp"; then
        if [ ! -d "$cache" ]; then
          mv "$tmp" "$cache" 2>/dev/null || true
        fi
      fi
      rm -rf "$tmp"
    fi

    if [ ! -d "$cache" ]; then
      echo "cdj3k-emu: could not stage writable resources in $cache" >&2
      exit 1
    fi
    printf '%s\n' "$cache"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "cdj3k-emu";
  inherit version;

  src = fetchurl {
    url = "https://github.com/nsaintot/cdj3k-emu/releases/download/v${version}/CDJ3K-Emulator-${version}-macos-universal.dmg";
    hash = "sha256-1yuCnbdUWZg4va+OQ7/XpMlPm//ubVVb+n/d5l/XTME=";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];

  # Patching the bundle or stripping its binaries invalidates the signature.
  dontPatchShebangs = true;
  dontStrip = true;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R "CDJ3K Emulator.app" $out/Applications/

    mkdir -p $out/bin
    makeWrapper "$out/Applications/CDJ3K Emulator.app/Contents/MacOS/cdj3k-emu" $out/bin/cdj3k-emu \
      --run "resources=\"\$(${stageResources} \"$out/Applications/CDJ3K Emulator.app/Contents/Resources\")\" || exit 1; export CDJ3K_RESOURCES=\"\$resources\""

    runHook postInstall
  '';

  meta = {
    description = "CDJ emulator that boots the stock firmware in QEMU with emulated controls, USB and Pro DJ Link";
    homepage = "https://github.com/nsaintot/cdj3k-emu";
    changelog = "https://github.com/nsaintot/cdj3k-emu/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "cdj3k-emu";
    platforms = lib.platforms.darwin;
  };
}
