{
  lib,
  undmg,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# Bump: take version from https://download.rbxport.com/latest.json, then prefetch
#   https://download.rbxport.com/rbxport-${version}-darwin-aarch64.dmg
#   https://download.rbxport.com/rbxport-${version}-darwin-x86_64.dmg
let
  version = "1.10.0";
  isArm = stdenvNoCC.hostPlatform.isAarch64;
in
stdenvNoCC.mkDerivation {
  pname = "rbxport";
  inherit version;

  src = fetchurl {
    url = "https://download.rbxport.com/rbxport-${version}-darwin-${
      if isArm then "aarch64" else "x86_64"
    }.dmg";
    hash =
      if isArm then
        "sha256-a2IcX+tV2Ln8MZ+UXukuWZC8z1NynQKenXebYRzVC7s="
      else
        "sha256-rHhVdCEnWxpBjYslkp2sLqkIGHGndObbYk5Xu0U5iiw=";
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
    makeWrapper $out/Applications/rbxport.app/Contents/MacOS/rbxport $out/bin/rbxport

    runHook postInstall
  '';

  meta = {
    description = "Rekordbox-compatible export-mode DJ library manager";
    homepage = "https://rbxport.com";
    changelog = "https://github.com/chrisle/rbxport/releases/tag/v${version}";
    license = lib.licenses.gpl2Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "rbxport";
    platforms = lib.platforms.darwin;
  };
}
