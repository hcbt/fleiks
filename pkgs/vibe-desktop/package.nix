{
  lib,
  undmg,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
}:

# Not built from source: closed-source Electron app, Apple silicon only.
# Repackage the upstream macOS dmg instead.
# Bump: read https://storage.googleapis.com/mistralai-ci-desktop-app/latest-mac.yml
# then prefetch https://storage.googleapis.com/mistralai-ci-desktop-app/vibe-${version}.dmg
#
# The built-in updater points at https://chat.mistral.ai/api/desktop/updates
# and cannot replace a Nix store bundle. Update through Nix.
let
  version = "1.2.0";
in
stdenvNoCC.mkDerivation {
  pname = "vibe-desktop";
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/mistralai-ci-desktop-app/vibe-${version}.dmg";
    hash = "sha256-uazG6YPB9eT7lDvF9Jko8sQvxMNZyWMnZJTS6QpfkqU=";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r Vibe.app $out/Applications

    mkdir -p $out/bin
    makeWrapper $out/Applications/Vibe.app/Contents/MacOS/Vibe $out/bin/vibe

    runHook postInstall
  '';

  meta = {
    description = "Mistral Vibe desktop app: AI chat and coding agent";
    homepage = "https://mistral.ai/products/vibe/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "vibe";
    platforms = [ "aarch64-darwin" ];
  };
}
