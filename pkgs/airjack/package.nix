{
  lib,
  darwin,
  fetchFromGitHub,
  python3Packages,
  airsnare,
  hashcat,
  hcxtools,
}:

let
  inherit (python3Packages)
    buildPythonApplication
    buildPythonPackage
    pyobjc-core
    pyobjc-framework-Cocoa
    prettytable
    pyfiglet
    python
    scapy
    setuptools
    ;

  # nixpkgs ships pyobjc-core and a subset of the framework wrappers. AirJack
  # needs CoreWLAN and CoreLocation, which are built from the same pyobjc
  # source tree so their versions stay in lockstep with pyobjc-core.
  pyobjcFramework =
    {
      name,
      description,
      imports,
    }:
    buildPythonPackage {
      pname = "pyobjc-framework-${name}";
      pyproject = true;

      inherit (pyobjc-core) version src;

      patches = pyobjc-core.patches or [ ];
      sourceRoot = "${pyobjc-core.src.name}/pyobjc-framework-${name}";

      build-system = [ setuptools ];

      buildInputs = [ darwin.libffi ];

      nativeBuildInputs = [
        darwin.DarwinTools # sw_vers
      ];

      # See the pyobjc-framework-Cocoa expression in nixpkgs.
      postPatch = ''
        substituteInPlace pyobjc_setup.py \
          --replace-fail "-buildversion" "-buildVersion" \
          --replace-fail "-productversion" "-productVersion" \
          --replace-fail "/usr/bin/sw_vers" "sw_vers" \
          --replace-fail "/usr/bin/xcrun" "xcrun"
      '';

      dependencies = [
        pyobjc-core
        pyobjc-framework-Cocoa
      ];

      env.NIX_CFLAGS_COMPILE = toString [
        "-I${darwin.libffi.dev}/include"
        "-Wno-error=unused-command-line-argument"
      ];

      pythonImportsCheck = imports;

      meta = {
        inherit description;
        homepage = "https://github.com/ronaldoussoren/pyobjc/tree/main/pyobjc-framework-${name}";
        license = lib.licenses.mit;
        platforms = lib.platforms.darwin;
      };
    };

  pyobjc-framework-CoreWLAN = pyobjcFramework {
    name = "CoreWLAN";
    description = "PyObjC wrappers for the CoreWLAN framework on macOS";
    imports = [ "CoreWLAN" ];
  };

  pyobjc-framework-CoreLocation = pyobjcFramework {
    name = "CoreLocation";
    description = "PyObjC wrappers for the CoreLocation framework on macOS";
    imports = [ "CoreLocation" ];
  };

  # nixpkgs marks hcxtools Linux-only, but it builds on Darwin; the install
  # target only needs $out/bin to exist first.
  hcxtoolsDarwin = hcxtools.overrideAttrs (old: {
    preInstall = (old.preInstall or "") + ''
      mkdir -p $out/bin
    '';
    meta = old.meta // {
      platforms = lib.platforms.darwin;
    };
  });
in
buildPythonApplication (finalAttrs: {
  pname = "airjack";
  version = "0-unstable-2026-08-19";

  src = fetchFromGitHub {
    owner = "rtulke";
    repo = "AirJack";
    rev = "92da55cff23415543a30003322c493afbfaeaced";
    hash = "sha256-vo5sn6dkX7a6hMQP6s2tsk9ktVd16TqNvYX1CXXWBPY=";
  };

  patches = [ ./diagnostics.patch ];

  # No setup.py or pyproject.toml upstream; install the script and man page.
  format = "other";
  dontBuild = true;
  # The bundled interpreter is copied and re-signed below.
  dontStrip = true;

  dependencies = [
    pyobjc-framework-CoreWLAN
    pyobjc-framework-CoreLocation
    pyobjc-framework-Cocoa
    prettytable
    pyfiglet
    scapy
  ];

  # AirJack finds these on PATH; zizzania remains an optional external backend.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${lib.makeBinPath [
      airsnare
      hashcat
      hcxtoolsDarwin
    ]}"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm644 airjack.py $out/share/airjack/airjack.py
    install -Dm644 airjack.1 $out/share/man/man1/airjack.1
    mkdir -p $out/bin

    # macOS only presents the Location Services prompt to a signed app bundle
    # with a usage description. A bare Nix Python binary is registered as the
    # client and never prompts, so run AirJack from a minimal bundle.
    app=$out/libexec/AirJack.app
    mkdir -p $app/Contents/MacOS
    cp -L ${lib.getExe python} $app/Contents/MacOS/AirJack
    chmod u+w $app/Contents/MacOS/AirJack
    ln -s ${python}/lib $app/Contents/lib

    cat > $app/Contents/Info.plist <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>dev.fleiks.airjack</string>
      <key>CFBundleName</key>
      <string>AirJack</string>
      <key>CFBundleDisplayName</key>
      <string>AirJack</string>
      <key>CFBundleExecutable</key>
      <string>AirJack</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleVersion</key>
      <string>${finalAttrs.version}</string>
      <key>CFBundleShortVersionString</key>
      <string>${finalAttrs.version}</string>
      <key>NSLocationUsageDescription</key>
      <string>AirJack needs location access to read Wi-Fi network BSSIDs.</string>
      <key>NSLocationWhenInUseUsageDescription</key>
      <string>AirJack needs location access to read Wi-Fi network BSSIDs.</string>
    </dict>
    </plist>
    EOF

    # Replace the process image with the bundled interpreter so the app
    # bundle, not the Nix Python binary, owns the Location Services request.
    cat > $out/bin/airjack <<EOF
    #!${python}/bin/python3
    import os
    import sys

    here = os.path.dirname(os.path.realpath(__file__))
    root = os.path.dirname(here)
    exe = os.path.join(root, "libexec", "AirJack.app", "Contents", "MacOS", "AirJack")
    script = os.path.join(root, "share", "airjack", "airjack.py")

    paths = [p for p in sys.path if p and "site-packages" in p]
    paths.append(os.environ.get("PYTHONPATH", ""))
    os.environ["PYTHONPATH"] = os.pathsep.join(paths)
    os.execv(exe, [exe, script] + sys.argv[1:])
    EOF
    chmod +x $out/bin/airjack

    runHook postInstall
  '';

  postFixup = ''
    export NIX_ORIG_PATH="$PATH"
    export PATH="/usr/bin:$PATH"
    codesign --force --sign - --identifier dev.fleiks.airjack "$out/libexec/AirJack.app"
    export PATH="$NIX_ORIG_PATH"
  '';

  meta = {
    description = "macOS Wi-Fi security testing tool for WPA/WPA2 handshake capture and cracking";
    homepage = "https://github.com/rtulke/AirJack";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "airjack";
    platforms = lib.platforms.darwin;
  };
})
