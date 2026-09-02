{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  # Bump: GET https://api.meta.ai/muse-code/channels/muse-stable
  # then GET that manifest_url and copy artifacts.<platform>.checksum.
  version = "1.0.2-R2040.1";

  sources = {
    aarch64-darwin = {
      file = "muse-aarch64-macos";
      hash = "sha256-QdN+SWDe8v4RdqlCkI9syqBPYC27ZlfFEceUq96hTMQ=";
    };
    x86_64-darwin = {
      file = "muse-x86-macos";
      hash = "sha256-SaLYDo+Zo181EnvpfScBpGvjp2LmOf8nLKhkMcuszh8=";
    };
    aarch64-linux = {
      file = "muse-aarch64-linux";
      hash = "sha256-sNqr1goo2zDFMLAdvPQYVgDzurKGGSxXqzD2qigtIPQ=";
    };
    x86_64-linux = {
      file = "muse-x86-linux";
      hash = "sha256-byRiPW0aGTqKuNYQw98Rw4zIu1SqObZTL7Knop2F0ns=";
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
