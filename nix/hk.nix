# hk pinned per project (skills/verifying-by-risk/hk-conventions.md). The tests
# amend hk@2.4.0's Config package, so the binary must be 2.4.0 too.
{ pkgs }:
let
  version = "2.4.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/jdx/hk/releases/download/v${version}/hk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-80WYZxykC+XDCDJKYO8wtzbbu/QlnftRGr15AJ7k3io=";
    };
  };
  system = pkgs.stdenv.hostPlatform.system;
  source = sources.${system} or (throw "nix/hk.nix: no hk ${version} binary is pinned for ${system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "hk";
  inherit version;
  src = pkgs.fetchurl source;
  sourceRoot = ".";
  installPhase = "install -Dm755 hk $out/bin/hk";
}
