{
  lib,
  undmg,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# Bump: take version from https://reckless-finch.spotifycdn.com/external/latest-mac.yml
# then prefetch
#   https://reckless-finch.spotifycdn.com/external/Xirp-${version}-arm64-external.dmg
#   https://reckless-finch.spotifycdn.com/external/Xirp-${version}-x64-external.dmg
let
  version = "0.32.0";
  isArm = stdenvNoCC.hostPlatform.isAarch64;
in
stdenvNoCC.mkDerivation {
  pname = "xirp";
  inherit version;

  src = fetchurl {
    url = "https://reckless-finch.spotifycdn.com/external/Xirp-${version}-${
      if isArm then "arm64" else "x64"
    }-external.dmg";
    hash =
      if isArm then
        "sha256-EB4blLkWM4AtHDJcExyKcGEzfe5eWweMxWpxlxaHDmY="
      else
        "sha256-B1ERFdEr/3nrrggPOghX1Migoi/lZ7vFCkqu4NpxVo4=";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r *.app $out/Applications

    mkdir -p $out/bin
    makeWrapper $out/Applications/Xirp.app/Contents/MacOS/Xirp $out/bin/xirp

    runHook postInstall
  '';

  meta = {
    description = "Spotify AI coding agent with Portal institutional memory";
    homepage = "https://xirp.spotify.com";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "xirp";
    platforms = lib.platforms.darwin;
  };
}
