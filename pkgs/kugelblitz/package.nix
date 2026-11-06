{
  lib,
  _7zz,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# Not built from source: closed-source app, Apple silicon only.
# Repackage the upstream macOS dmg instead, like buzz.
# Bump: take the version from https://apps.metaebene.me/en/kugelblitz,
# then prefetch the dmg.
#
# The dmg is APFS and undmg only reads HFS, so unpack with 7zz.
let
  version = "1.0.2";
in
stdenvNoCC.mkDerivation {
  pname = "kugelblitz";
  inherit version;

  src = fetchurl {
    url = "https://apps.metaebene.me/dl/kugelblitz/${version}/Kugelblitz-${version}.dmg";
    hash = "sha256-lEHfX2Ca89wCILxTjdVNtONhrMLdx1nksFMmq7joXGM=";
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
    cp -r Kugelblitz.app $out/Applications

    mkdir -p $out/bin
    makeWrapper $out/Applications/Kugelblitz.app/Contents/MacOS/Kugelblitz $out/bin/kugelblitz

    runHook postInstall
  '';

  meta = {
    description = "The Earth and its neighbors as a 3D globe and atlas, with open geodata on real terrain";
    homepage = "https://apps.metaebene.me/en/kugelblitz";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "kugelblitz";
    platforms = [ "aarch64-darwin" ];
  };
}
