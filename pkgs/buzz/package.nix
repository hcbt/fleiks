{
  lib,
  _7zz,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# Not built from source: upstream needs Python 3.12, five git submodules
# (whisper.cpp binaries and a C++ forced-aligner extension built by the hatch
# hook), and dependencies nixpkgs lacks (stable-ts, nemo-toolkit-asr,
# lameenc, lhotse, …) at pins it does not match (numpy <2, torch ==2.8.0).
# Repackage the upstream macOS dmg instead, like xirp.
# Bump: take version from https://github.com/chidiwilliams/buzz/releases,
# then prefetch both dmg hashes. 1.4.5 is the last Intel Mac build;
# the next bump drops the X64 dmg.
#
# The dmg is APFS and undmg only reads HFS, so unpack with 7zz. -snld20
# permits the ../Frameworks symlinks PyInstaller writes between
# Contents/Resources and Contents/Frameworks, which 7zz otherwise drops
# as "dangerous link paths".
let
  version = "1.4.5";
  isArm = stdenvNoCC.hostPlatform.isAarch64;
in
stdenvNoCC.mkDerivation {
  pname = "buzz";
  inherit version;

  src = fetchurl {
    url = "https://github.com/chidiwilliams/buzz/releases/download/v${version}/Buzz-${version}-mac-${
      if isArm then "ARM64" else "X64"
    }.dmg";
    hash =
      if isArm then
        "sha256-23BQWBRMhZ4V1BDhGit6S2+utplKq46BAb0LtaBaBqg="
      else
        "sha256-FN4F5H6rz4oYO6ookLEess3iNpv/+ZL9E3Wo8FFJHo0=";
  };

  nativeBuildInputs = [
    _7zz
    makeWrapper
  ];

  unpackPhase = ''
    runHook preUnpack
    7zz x -y -snld20 $src
    runHook postUnpack
  '';

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r Buzz.app $out/Applications

    mkdir -p $out/bin
    makeWrapper $out/Applications/Buzz.app/Contents/MacOS/Buzz $out/bin/buzz

    runHook postInstall
  '';

  meta = {
    description = "Transcribe and translate audio offline, powered by OpenAI Whisper";
    homepage = "https://github.com/chidiwilliams/buzz";
    changelog = "https://github.com/chidiwilliams/buzz/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "buzz";
    platforms = lib.platforms.darwin;
  };
}
