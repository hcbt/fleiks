{
  lib,
  undmg,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# The macOS installer at https://store.steampowered.com/about/ is an
# unversioned bootstrap dmg: Steam.app (x86_64, Rosetta on Apple Silicon)
# downloads the real client on first launch. `version` is the bundle's
# CFBundleVersion; it rarely changes, so the hash is the real pin.
# Bump: prefetch the url below and update the hash.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "steam";
  version = "6.0";

  src = fetchurl {
    url = "https://cdn.akamai.steamstatic.com/client/installer/steam.dmg";
    hash = "sha256-4av7qqe+Pg9IoODUwxMjPgWGGx0mrzKDDdyDi+iPJpE=";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r Steam.app $out/Applications

    mkdir -p $out/bin
    makeWrapper $out/Applications/Steam.app/Contents/MacOS/steam_osx $out/bin/steam

    runHook postInstall
  '';

  meta = {
    description = "Steam client for macOS";
    homepage = "https://store.steampowered.com/about/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "steam";
    platforms = lib.platforms.darwin;
  };
})
