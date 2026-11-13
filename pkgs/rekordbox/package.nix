{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  xar,
  cpio,
  gzip,
  makeWrapper,
}:

# Bump: the cask in brew-api carries version and sha256. The download is
#   https://cdn.rekordbox.com/files/<build>/Install_rekordbox_<version>.pkg_.zip
# where <version> uses underscores. The zip wraps a product-archive pkg whose
# payload is the contents of /Applications/rekordbox 7; only the .app is kept.
let
  version = "7.2.19";
  build = "20260914095016";
in
stdenvNoCC.mkDerivation {
  pname = "rekordbox";
  inherit version;

  src = fetchurl {
    url = "https://cdn.rekordbox.com/files/${build}/Install_rekordbox_7_2_19.pkg_.zip";
    hash = "sha256-F9m/Ucdd9vBr5z8DnHrNlby7JwDBD/Oc82ADT+yKLgM=";
  };

  nativeBuildInputs = [
    unzip
    xar
    cpio
    gzip
    makeWrapper
  ];

  # Patching the bundle invalidates its code signature.
  dontPatchShebangs = true;
  dontStrip = true;

  unpackPhase = ''
    unzip -q "$src"
    xar -xf ./*.pkg
    gzip -dc ./*.pkg/Payload | cpio -idm
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R rekordbox.app $out/Applications/

    # Nix canonicalises store files to 0444. rekordbox copies
    # Contents/Resources/{master,product}.db into ~/Library/Pioneer/rekordbox on
    # first launch and opens them read-write; a copy that inherits 0444 fails
    # with "Unable to open the database file". Seed writable copies first.
    mkdir -p $out/bin
    makeWrapper $out/Applications/rekordbox.app/Contents/MacOS/rekordbox $out/bin/rekordbox \
      --run 'data="$HOME/Library/Pioneer/rekordbox"; mkdir -p "$data"; for f in master.db product.db; do [ -e "$data/$f" ] || cp "'"$out"'/Applications/rekordbox.app/Contents/Resources/$f" "$data/$f"; chmod u+w "$data/$f" 2>/dev/null || true; done'

    runHook postInstall
  '';

  meta = {
    description = "Pioneer DJ rekordbox";
    homepage = "https://rekordbox.com";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "rekordbox";
    platforms = lib.platforms.darwin;
  };
}
