{
  lib,
  stdenv,
  swift,
  swiftpm,
  fetchFromGitHub,
  fetchurl,
  unzip,
  python3,
  makeWrapper,
}:

# Upstream source, built with the SDK pkgs.swift propagates (apple-sdk 26).
# apple-sdk-26.patch drops ToolbarItem.visibilityPriority, which that SDK's
# SwiftUI does not have, and splits view bodies the nixpkgs Swift cannot
# type-check as one expression. The build expands string catalogs to .lproj;
# that SDK cannot compile xcstrings. Payload is the v1.2.1 release zip
# (building it needs a Wine tree and Dobby). srcRev is the latest commit
# after that tag.
let
  version = "1.2.1";
  srcRev = "b2f49e46ee874013b2818c32405e713f6fbfb68e";
  sparkleRev = "eef1a539a373c1f1a320624b1130fc5de7b2e100";
in
stdenv.mkDerivation {
  pname = "notproton";
  inherit version;

  src = fetchFromGitHub {
    owner = "NotProtonNot";
    repo = "NotProton";
    rev = srcRev;
    hash = "sha256-qeAjgAVCCNU8MKUJPbi3XlWd+hU/Q+cStt4tYnBL2G4=";
  };

  patches = [ ./apple-sdk-26.patch ];

  payload = fetchurl {
    url = "https://github.com/NotProtonNot/NotProton/releases/download/v${version}/NotProton.zip";
    hash = "sha256-QroXc3GbX3PAAY4k33Q9Et4iLgyPcRXtgVp/xq4wjfE=";
  };

  sparkle = fetchFromGitHub {
    owner = "sparkle-project";
    repo = "Sparkle";
    rev = sparkleRev;
    hash = "sha256-8AWJAue55l+sie0hQ+isH/LYxd9fxBKbGAq15gxn6Dg=";
  };

  sparkleZip = fetchurl {
    url = "https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-for-Swift-Package-Manager.zip";
    hash = "sha256-F+KDErjhirfNu+Cab7KMxVpUeexsNx28B83s0qFP2Vk=";
  };

  nativeBuildInputs = [
    swift
    swiftpm
    unzip
    python3
    makeWrapper
  ];

  dontPatchShebangs = true;
  dontUseSwiftpmBuild = true;
  dontUseSwiftpmInstall = true;

  buildPhase = ''
    runHook preBuild

    unzip -q $payload -d payload-zip
    cp -R payload-zip/NotProton.app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/Contents/Resources/payload \
      app/Sources/NotProtonApp/Resources/payload
    chmod -R u+w app/Sources/NotProtonApp/Resources/payload

    mkdir -p app/.build/checkouts app/.build/artifacts/sparkle/Sparkle
    cp -R $sparkle app/.build/checkouts/Sparkle
    chmod -R u+w app/.build/checkouts/Sparkle
    unzip -q $sparkleZip -d sparkle-zip
    cp -R sparkle-zip/Sparkle.xcframework app/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework

    python3 - << 'PY'
    import json, os
    root = os.getcwd()
    state = {
      "version": 7,
      "object": {
        "artifacts": [{
          "kind": {"xcframework": {}},
          "packageRef": {
            "identity": "sparkle",
            "kind": "remoteSourceControl",
            "location": "https://github.com/sparkle-project/Sparkle",
            "name": "Sparkle",
          },
          "path": f"{root}/app/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework",
          "source": {
            "checksum": "17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959",
            "type": "remote",
            "url": "https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-for-Swift-Package-Manager.zip",
          },
          "targetName": "Sparkle",
        }],
        "dependencies": [{
          "basedOn": None,
          "packageRef": {
            "identity": "sparkle",
            "kind": "remoteSourceControl",
            "location": "https://github.com/sparkle-project/Sparkle",
            "name": "Sparkle",
          },
          "state": {
            "name": "sourceControlCheckout",
            "checkoutState": {
              "revision": "eef1a539a373c1f1a320624b1130fc5de7b2e100",
              "version": "2.10.0",
            },
          },
          "subpath": "Sparkle",
        }],
        "prebuilts": [],
      },
    }
    os.makedirs("app/.build", exist_ok=True)
    with open("app/.build/workspace-state.json", "w") as f:
      json.dump(state, f)
    PY
    python3 - << 'PY'
    import json
    from pathlib import Path

    root = Path("app/Sources/NotProtonApp/Resources/Localization")
    catalog = json.loads((root / "Localizable.xcstrings").read_text())
    source = catalog.get("sourceLanguage", "en")
    strings = catalog.get("strings", {})
    langs = {source}
    for entry in strings.values():
        langs.update(entry.get("localizations") or {})

    def escape(text):
        return (
            text.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
        )

    def translated(entry, lang, key):
        loc = (entry.get("localizations") or {}).get(lang) or {}
        unit = loc.get("stringUnit") or {}
        if "value" in unit:
            return unit["value"]
        if lang == source:
            return key
        return None

    for lang in sorted(langs):
        lines = []
        for key, entry in strings.items():
            value = translated(entry, lang, key)
            if value is None:
                continue
            lines.append(f'"{escape(key)}" = "{escape(value)}";')
        dest = root / f"{lang}.lproj"
        dest.mkdir(exist_ok=True)
        (dest / "Localizable.strings").write_text("\n".join(lines) + "\n")

    (root / "Localizable.xcstrings").unlink()
    PY

    TERM=dumb swift build --package-path app -c release --disable-sandbox

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    bin=$(swift build --package-path app -c release --disable-sandbox --show-bin-path)
    app=$out/Applications/NotProton.app
    mkdir -p $app/Contents/MacOS $app/Contents/Resources $app/Contents/Frameworks

    cp app/Info.plist $app/Contents/Info.plist
    /usr/libexec/PlistBuddy \
      -c "Set :CFBundleShortVersionString ${version}" \
      -c "Set :CFBundleVersion ${version}" \
      $app/Contents/Info.plist

    cp $bin/NotProtonApp $app/Contents/MacOS/NotProtonApp
    cp -R $bin/Sparkle.framework $app/Contents/Frameworks/Sparkle.framework
    install_name_tool -add_rpath @executable_path/../Frameworks $app/Contents/MacOS/NotProtonApp
    cp -R $bin/NotProtonApp_NotProtonApp.bundle $app/Contents/Resources/
    cp payload-zip/NotProton.app/Contents/Resources/Assets.car \
      payload-zip/NotProton.app/Contents/Resources/NotProton.icns \
      $app/Contents/Resources/

    /usr/bin/codesign -f -s - $app
    /usr/bin/codesign --verify --strict $app

    mkdir -p $out/bin
    makeWrapper $app/Contents/MacOS/NotProtonApp $out/bin/notproton

    runHook postInstall
  '';

  meta = {
    description = "Steam Play for macOS Steam via CrossOver";
    homepage = "https://github.com/NotProtonNot/NotProton";
    changelog = "https://github.com/NotProtonNot/NotProton/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "notproton";
    platforms = [ "aarch64-darwin" ];
  };
}
