with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "Google";
  src  = ./public;
  installPhase = ''
    mkdir -p "$out/"
  	cp -ra * "$out/"
    chmod -R 755 "$out/"
  '';
}
