{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  # Bump: GET https://api.meta.ai/muse-code/channels/muse-stable
  # then GET that manifest_url and copy artifacts.<platform>.checksum.
  version = "1.4.0-R4302.1";

  sources = {
    aarch64-darwin = {
      file = "muse-aarch64-macos";
      hash = "sha256-t+Hr32tcfmfduP9LkXRh9VV1hUXH2yUHazaW2EAY11I=";
    };
    x86_64-darwin = {
      file = "muse-x86-macos";
      hash = "sha256-ZI2Pi31/lE4R3aEWsYM+mkzi51PI1I21fwwCALEuchM=";
    };
    aarch64-linux = {
      file = "muse-aarch64-linux";
      hash = "sha256-ec+6G55BezcL25FUpUbFJLfzKjQCbmFktvPxIvDqM4Y=";
    };
    x86_64-linux = {
      file = "muse-x86-linux";
      hash = "sha256-rSHCKWX4YAtEc7Srg1T/fMSD1MtoG0bylSVh2FXI7YY=";
    };
  };

  srcInfo =
    sources.${stdenv.hostPlatform.system}
      or (throw "muse-code: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "muse-code";
  inherit version;

  src = fetchurl {
    name = "muse-${version}";
    url = "https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version=${version}&file=${srcInfo.file}";
    inherit (srcInfo) hash;
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/muse
    runHook postInstall
  '';

  meta = {
    description = "Meta's terminal coding agent";
    homepage = "https://dev.meta.ai/docs/muse-code";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "muse";
    platforms = lib.attrNames sources;
  };
}
