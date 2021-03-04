{ src ? null, system ? builtins.currentSystem }:
let
  # On Hercules CI, build for multiple systems
  multiSystemBuild = src != null;

  ci = system: _: {
    cachix = import ./default.nix { inherit system; };
    pre-commit-check = (import ./nix { inherit system; }).pre-commit-check;
    recurseForDerivations = true;
  };

  ciSystems = {
    "x86_64-linux" = {};
    "aarch64-linux" = {};
    "x86_64-darwin" = {};
  };
in
  if multiSystemBuild
  then builtins.mapAttrs ci ciSystems
  else ci system {}
