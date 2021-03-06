{
  stdenv,
  lib,
  meson,
  ninja,
  pkgconfig,
  git,
  asciidoc,
  libxslt,
  docbook_xsl,
  scdoc,
  wayland,
  wayland-protocols,
  libxkbcommon,
  cairo,
  pam,
  gdk-pixbuf,
  inputs,
  buildDocs ? true,
}: let
  version = inputs.swaylock.rev;
in
  stdenv.mkDerivation {
    name = "swaylock-${version}";
    inherit version;

    src = inputs.swaylock;

    nativeBuildInputs =
      [meson ninja pkgconfig git]
      ++ lib.optional buildDocs [scdoc asciidoc libxslt docbook_xsl];
    buildInputs = [wayland wayland-protocols cairo pam gdk-pixbuf libxkbcommon];

    mesonFlags = ["-Dauto_features=enabled"];

    enableParallelBuilding = true;

    meta = {
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  }
