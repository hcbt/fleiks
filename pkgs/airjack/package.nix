{
  lib,
  darwin,
  fetchFromGitHub,
  python3Packages,
  hashcat,
}:

let
  inherit (python3Packages)
    buildPythonApplication
    buildPythonPackage
    pyobjc-core
    pyobjc-framework-Cocoa
    prettytable
    pyfiglet
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

  # No setup.py or pyproject.toml upstream; install the script and man page.
  format = "other";
  dontBuild = true;

  dependencies = [
    pyobjc-framework-CoreWLAN
    pyobjc-framework-CoreLocation
    pyobjc-framework-Cocoa
    prettytable
    pyfiglet
    scapy
  ];

  # AirSnare and zizzania are not in nixpkgs; hashcat is, and AirJack finds
  # hcxpcapngtool on PATH when hcxtools is installed.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${lib.makeBinPath [ hashcat ]}"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 airjack.py $out/bin/airjack
    install -Dm644 airjack.1 $out/share/man/man1/airjack.1

    runHook postInstall
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
