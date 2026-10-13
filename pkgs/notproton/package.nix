{
  lib,
  unzip,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# Source build needs Xcode 27, a pinned Dobby checkout, Wine trees, mingw-w64,
# and fontforge, so package the upstream release zip like utm/xirp.
# Bump: take version and the NotProton.zip sha256 digest from
# https://github.com/NotProtonNot/NotProton/releases
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "notproton";
  version = "1.1.7";

  src = fetchurl {
    url = "https://github.com/NotProtonNot/NotProton/releases/download/v${finalAttrs.version}/NotProton.zip";
    hash = "sha256-3xFvUYX7V7b2+P9fWTuYUe22l6AXd+QD4f0jGF+b2/8=";
  };

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  # Patching the payload `run` script inside the bundle would break its
  # code signature.
  dontPatchShebangs = true;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r NotProton.app $out/Applications

    mkdir -p $out/bin
    makeWrapper $out/Applications/NotProton.app/Contents/MacOS/NotProtonApp $out/bin/notproton

    runHook postInstall
  '';

  meta = {
    description = "Steam Play for macOS Steam via CrossOver";
    homepage = "https://github.com/NotProtonNot/NotProton";
    changelog = "https://github.com/NotProtonNot/NotProton/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "notproton";
    platforms = [ "aarch64-darwin" ];
  };
})
