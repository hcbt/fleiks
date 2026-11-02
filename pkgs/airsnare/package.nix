{
  lib,
  stdenv,
  fetchFromGitHub,
  libpcap,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "airsnare";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "rtulke";
    repo = "airsnare";
    tag = "v${finalAttrs.version}";
    hash = "sha256-98k/2JXd5+R3XLqB8fNgkEzSTeviJxN5w6CS/CjmS/o=";
  };

  buildInputs = [ libpcap ];

  # `make install` depends on the release profile, which builds the C and
  # Objective-C sources (CoreWLAN channel setting on macOS).
  installFlags = [ "INSTALL_DIR=${placeholder "out"}/bin" ];

  meta = {
    description = "WPA handshake capture tool with deauthentication";
    homepage = "https://github.com/rtulke/airsnare";
    changelog = "https://github.com/rtulke/airsnare/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "airsnare";
    platforms = lib.platforms.darwin;
  };
})
