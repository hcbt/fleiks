{
  lib,
  undmg,
  makeWrapper,
  fetchurl,
  stdenvNoCC,
  notproton,
}:

# The macOS installer at https://store.steampowered.com/about/ is an
# unversioned bootstrap dmg: Steam.app (x86_64, Rosetta on Apple Silicon)
# downloads the real client on first launch. `version` is the bundle's
# CFBundleVersion; it rarely changes, so the hash is the real pin.
# Bump: prefetch the url below and update the hash.
#
# The bundle is pre-patched for NotProton at build time, replicating what
# NotProton's installer does at runtime (SteamInstaller in upstream):
# copy notproton.dylib into Contents/MacOS, set DYLD_INSERT_LIBRARIES and
# the controller block in Info.plist's LSEnvironment, then ad-hoc sign
# the dylib, steam_osx and the bundle, in that order. NotProton detects
# this state (insert string + dylib hash, ignoring signature) and skips
# patching, which is what allows Steam to live in nix-darwin's read-only
# /Applications/Nix Apps instead of a writable /Applications copy. The
# insert path is therefore pinned to that install location; launching
# the store copy directly still works because the path resolves once
# nix-darwin has installed the app. The dylib comes from the notproton
# package, so bumping notproton rebuilds this package with the matching
# dylib and NotProton never needs to update it in place.
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

    app=$out/Applications/Steam.app
    payload=${notproton}/Applications/NotProton.app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/payload
    install -m 755 $payload/notproton.dylib $app/Contents/MacOS/notproton.dylib

    plist=$app/Contents/Info.plist
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string '/Applications/Nix Apps/Steam.app/Contents/MacOS/notproton.dylib'" $plist
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:SDL_JOYSTICK_BLACKLIST_DEVICES string '0x05ac/0x0004'" $plist

    /usr/bin/codesign -f -s - $app/Contents/MacOS/notproton.dylib
    /usr/bin/codesign -f -s - $app/Contents/MacOS/steam_osx
    /usr/bin/codesign -f -s - $app

    mkdir -p $out/bin
    makeWrapper $app/Contents/MacOS/steam_osx $out/bin/steam

    runHook postInstall
  '';

  meta = {
    description = "Steam client for macOS, pre-patched for NotProton";
    homepage = "https://store.steampowered.com/about/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "steam";
    platforms = lib.platforms.darwin;
  };
})
