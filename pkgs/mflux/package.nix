{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

# nixpkgs python3Packages.mflux is still 0.15.4 from filipstrand/mflux.
# This is the community continuation.
# Bump: take version from https://github.com/mflux-community/mflux/releases,
# then the src hash. Tag is v.<version>, not v<version>.
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "mflux";
  version = "0.20.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mflux-community";
    repo = "mflux";
    tag = "v.${finalAttrs.version}";
    hash = "sha256-lKnGhtEZYxrdTARfZa0sN4zVqDQFLC+2xzVNw1ddmZQ=";
  };

  # nixpkgs uv-build is 0.11.28; it already implements the build-backend
  # settings this release uses (namespace, source-exclude, module-name).
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "uv_build>=0.12.5,<0.13.0" "uv_build"
  '';

  build-system = with python3Packages; [ uv-build ];

  # Source mlx is built with MLX_BUILD_METAL=false. The Metal shader
  # compiler is not in the Nix sandbox, and this machine has no Metal
  # toolchain, so a from-source Metal build cannot run. mlx-bin is the
  # same 0.32.0 release with the Metal runtime.
  pythonRelaxDeps = [ "mlx" ];

  dependencies = with python3Packages; [
    anyio
    filelock
    fonttools
    hf-transfer
    huggingface-hub
    matplotlib
    mlx-bin
    numpy
    opencv-python
    piexif
    pillow
    platformdirs
    protobuf
    pyyaml
    regex
    requests
    safetensors
    sentencepiece
    tokenizers
    toml
    torch
    tqdm
    transformers
    urllib3
  ];

  pythonImportsCheck = [ "mflux" ];

  # The suite downloads models. --help proves the console scripts import.
  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/mflux-generate --help | grep -F -- '--prompt'
    $out/bin/mflux-generate-z-image-turbo --help | grep -F -- '--prompt'
    $out/bin/mflux-capabilities --help | grep -F -- '--format'
    runHook postInstallCheck
  '';

  meta = {
    description = "MLX native implementations of state-of-the-art generative image models";
    homepage = "https://github.com/mflux-community/mflux";
    changelog = "https://github.com/mflux-community/mflux/releases/tag/v.${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "mflux-generate";
    # Intel Macs are gone from nixpkgs, and MLX has no x86_64-darwin build.
    # Linux wants mlx[cuda13], which nixpkgs does not ship.
    platforms = [ "aarch64-darwin" ];
  };
})
