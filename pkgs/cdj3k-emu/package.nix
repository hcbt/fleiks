{
  lib,
  undmg,
  makeWrapper,
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
    makeWrapper "$out/Applications/CDJ3K Emulator.app/Contents/MacOS/cdj3k-emu" $out/bin/cdj3k-emu

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
