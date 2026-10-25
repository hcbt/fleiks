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
  version = "0.23.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mflux-community";
    repo = "mflux";
    tag = "v.${finalAttrs.version}";
    hash = "sha256-TxHnWwlTAPcrzI3vTXyBn7kMB0dCjdD/9qS42KeWc7Y=";
  };

  build-system = with python3Packages; [ uv-build ];

  # Source mlx is built with MLX_BUILD_METAL=false. nixpkgs mlx is 0.32.3.
  # The Metal shader compiler is not in the Nix sandbox, and this machine
  # has no Metal toolchain, so a from-source Metal build cannot run.
  # mlx-bin is the 0.32.0 Metal wheel.
  # nixpkgs urllib3 is 2.7.0; upstream floors it at 2.8.0.
  pythonRelaxDeps = [
    "mlx"
    "urllib3"
  ];

  dependencies = with python3Packages; [
    anyio
    filelock
    fonttools
    fsspec
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
