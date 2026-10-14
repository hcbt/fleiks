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
# SwiftUI does not have, and splits the view bodies Swift 6.2.4 cannot
# type-check as one expression. The injected payload is the v1.1.7 release
# payload: building it needs a Wine tree and Dobby.
let
  version = "1.1.7";
  srcRev = "86097bdcd028f1a47db751cedc7001785b97db4e";
  sparkleRev = "eef1a539a373c1f1a320624b1130fc5de7b2e100";
in
stdenv.mkDerivation {
  pname = "notproton";
  inherit version;

  src = fetchFromGitHub {
    owner = "NotProtonNot";
    repo = "NotProton";
    rev = srcRev;
    hash = "sha256-4/K7ulIaMCXnIkxj+7BuYnkVoFNoLEmJpKF8/unh27s=";
  };

  patches = [ ./apple-sdk-26.patch ];

  payload = fetchurl {
    url = "https://github.com/NotProtonNot/NotProton/releases/download/v${version}/NotProton.zip";
    hash = "sha256-3xFvUYX7V7b2+P9fWTuYUe22l6AXd+QD4f0jGF+b2/8=";
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
    mkdir -p $app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/Contents/Resources
    cp -R $app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/payload \
      $app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/Contents/Resources/payload
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
