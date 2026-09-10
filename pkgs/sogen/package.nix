{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  python3,
  pkg-config,
  sdl3,
}:
stdenv.mkDerivation {
  pname = "sogen";
  version = "0-unstable-2026-09-09";

  src = fetchFromGitHub {
    owner = "momo5502";
    repo = "sogen";
    rev = "13fbcb7dafa7b3dc1b898a523603f9a24cf84a7c";
    fetchSubmodules = true;
    hash = "sha256-7Uumgy0otx4H/eX812UGYfeTwdm4BAjrH1G+KE4tHbc=";
  };

  # FEX requires its git hash even when building an exported source tree.
  # Keep fex-version.patch in sync with the pinned deps/FEX submodule.
  patches = [
    ./install.patch
    ./fex-version.patch
  ];
  nativeBuildInputs = [
    cmake
    ninja
    python3
    pkg-config
  ];
  buildInputs = [ sdl3 ];
  cmakeFlags = [
    (lib.cmakeBool "SOGEN_BUILD_STATIC" true)
    (lib.cmakeBool "SOGEN_ENABLE_RUST_CODE" false)
    (lib.cmakeBool "SOGEN_ENABLE_STEAM" false)
    (lib.cmakeBool "SOGEN_ENABLE_LTO" false)
    (lib.cmakeBool "SOGEN_ENABLE_AVX2" false)
    (lib.cmakeBool "CMAKE_SKIP_INSTALL_ALL_DEPENDENCY" true)
  ];
  ninjaFlags = [ "analyzer" ];
  installTargets = [ "sogen-install" ];

  meta = {
    description = "Windows and Linux userspace emulator";
    homepage = "https://github.com/momo5502/sogen";
    license = lib.licenses.gpl2Only;
    mainProgram = "analyzer";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
