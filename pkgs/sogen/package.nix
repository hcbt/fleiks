{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchzip,
  cmake,
  ninja,
  python3,
  pkg-config,
  sdl3,
  pkgsCross,
  replaceVars,
}:
let
  emulationRoot = fetchzip {
    url = "https://sogen.dev/root.zip";
    hash = "sha256-0na5TQzkLw69FhDpyhTm7Rqz8cvRavSefH7VwjN8gXg=";
  };
  steamworks = fetchFromGitHub {
    owner = "ValveSoftware";
    repo = "Proton";
    rev = "5b89db940e0ebe3a137a6009a3589232fe084c09";
    hash = "sha256-VSxOPicISnyoN3v62OIztwX5gN6nD+qXPxqT2Xdnp94=";
  };
in
stdenv.mkDerivation {
  pname = "sogen";
  version = "0-unstable-2026-10-25";

  src = fetchFromGitHub {
    owner = "momo5502";
    repo = "sogen";
    rev = "258c531549fd7513c5698b2bbf4fb1fc2a080fea";
    fetchSubmodules = true;
    hash = "sha256-NaT0pGfwiKI2APxECFcN5wLoqa8q5Di+FSIz3YOGIUI=";
  };

  # FEX requires its git hash even when building an exported source tree.
  # Keep fex-version.patch in sync with the pinned deps/FEX submodule.
  patches = [
    ./install.patch
    ./fex-version.patch
    ./ntdeletekey.patch
    ./ntdeletekey-registration.patch
    (replaceVars ./root-path.patch { sogenRoot = emulationRoot; })
    (replaceVars ./steam-headers.patch {
      mingwHeaders = pkgsCross.mingwW64.windows.mingw_w64_headers;
    })
  ];
  nativeBuildInputs = [
    cmake
    ninja
    (python3.withPackages (ps: [ ps.clang ]))
    pkg-config
  ];
  buildInputs = [ sdl3 ];
  # HVF ad-hoc signs with codesign, which lives in /usr/bin and is not on PATH.
  # Restore PATH afterwards so fixup keeps nix's find and cut.
  preBuild = ''
    export NIX_ORIG_PATH="$PATH"
    export PATH="/usr/bin:$PATH"
  '';
  postBuild = ''
    export PATH="$NIX_ORIG_PATH"
  '';
  cmakeFlags = [
    (lib.cmakeBool "SOGEN_BUILD_STATIC" true)
    (lib.cmakeBool "SOGEN_ENABLE_RUST_CODE" false)
    (lib.cmakeBool "SOGEN_ENABLE_STEAM" true)
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_STEAMWORKS_SNAPSHOTS" "${steamworks}")
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
