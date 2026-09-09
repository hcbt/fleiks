{
  lib,
  undmg,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# nixpkgs utm is still 4.7.5. This is the GitHub v5.0.5 (beta) dmg.
# Bump: take version from https://github.com/utmapp/UTM/releases and the
# UTM.dmg sha256 from that release's asset digest.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "utm";
  version = "5.0.5";

  src = fetchurl {
    url = "https://github.com/utmapp/UTM/releases/download/v${finalAttrs.version}/UTM.dmg";
    hash = "sha256-cTr+c8cR8BNEuHZmVL5THNOR7S4wkxIG9DtRWfFDdk8=";
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
    for bin in $out/Applications/UTM.app/Contents/MacOS/*; do
      # Symlinking `UTM` doesn't work; seems to look for files in the wrong
      # place
      makeWrapper $bin "$out/bin/$(basename $bin)"
    done

    runHook postInstall
  '';

  meta = {
    description = "Full featured system emulator and virtual machine host for iOS and macOS";
    homepage = "https://mac.getutm.app/";
    changelog = "https://github.com/utmapp/utm/releases/tag/v${finalAttrs.version}";
    mainProgram = "UTM";
    license = lib.licenses.asl20;
    platforms = lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})

