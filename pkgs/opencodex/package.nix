{
  lib,
  stdenv,
  stdenvNoCC,
  fetchzip,
  fetchurl,
  bun,
  nodejs,
  makeBinaryWrapper,
  autoPatchelfHook,
  openssl,
  versionCheckHook,
}:

let
  bunTarget =
    {
      aarch64-darwin = "darwin-aarch64";
      x86_64-darwin = "darwin-x64";
      aarch64-linux = "linux-aarch64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "opencodex: unsupported system ${stdenv.hostPlatform.system}");

  napiTarget =
    {
      aarch64-darwin = "darwin-arm64";
      x86_64-darwin = "darwin-x64";
      aarch64-linux = "linux-arm64-gnu";
      x86_64-linux = "linux-x64-gnu";
    }
    .${stdenv.hostPlatform.system}
      or (throw "opencodex: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "opencodex";
  version = "2.48.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@bitkyc08/opencodex/-/opencodex-${finalAttrs.version}.tgz";
    hash = "sha256-FbaJH/wnRPymDxdIrW5OQyAy7KNzq5kqzUeDeS4u7Yc=";
  };

  bunLock = fetchurl {
    url = "https://raw.githubusercontent.com/lidge-jun/opencodex/v${finalAttrs.version}/bun.lock";
    hash = "sha256-HIdjsKP3ZdVGQlOL7cjncAcHhQdwE5mKnH0b2PFJmJc=";
  };

  # Bump: npm view @bitkyc08/opencodex version, then src, bunLock, and
  # passthru.node_modules outputHash.
  passthru.node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars;

    nativeBuildInputs = [ bun ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      cp ${finalAttrs.bunLock} bun.lock
      bun install \
        --cpu="*" \
        --os="*" \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress \
        --production
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R node_modules $out/
      runHook postInstall
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-ZFlRUKAf8FU49H1kkGeLWvHo++tokDpGrRT8XM3w0I8=";
  };

  nativeBuildInputs = [
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ openssl ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    dest=$out/lib/node_modules/@bitkyc08/opencodex
    mkdir -p "$dest"
    cp -R . "$dest"
    chmod -R u+w "$dest"
    cp -R ${finalAttrs.passthru.node_modules}/node_modules "$dest/"
    chmod -R u+w "$dest/node_modules"

    if [ -d "$dest/node_modules/@oven" ]; then
      find "$dest/node_modules/@oven" -mindepth 1 -maxdepth 1 ! -name "bun-${bunTarget}" -exec rm -rf {} +
    fi
    if [ -d "$dest/node_modules/@napi-rs" ]; then
      find "$dest/node_modules/@napi-rs" -mindepth 1 -maxdepth 1 -name 'keyring-*' ! -name "keyring-${napiTarget}" -exec rm -rf {} +
    fi

    bunBin=$dest/node_modules/@oven/bun-${bunTarget}/bin/bun
    chmod +x "$bunBin"
    mkdir -p "$dest/node_modules/bun/bin"
    cp "$bunBin" "$dest/node_modules/bun/bin/bun.exe"
    chmod +x "$dest/node_modules/bun/bin/bun.exe"

    makeBinaryWrapper ${lib.getExe nodejs} "$out/bin/ocx" \
      --add-flags "$dest/bin/ocx.mjs" \
      --set OPENCODEX_BUN_PATH "$bunBin"
    ln -s ocx "$out/bin/opencodex"

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  meta = {
    description = "Universal provider proxy for OpenAI Codex, Claude Code, Claude Desktop, and Grok Build";
    homepage = "https://github.com/lidge-jun/opencodex";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    mainProgram = "ocx";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
