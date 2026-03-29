{ nixpkgs }:
let
  # All systems commonly targeted by Nix flakes.
  # Filtered at eval time to those where Flutter is available in nixpkgs.
  allSystems = [
    "x86_64-linux"      "x86_64-darwin"
    "aarch64-linux"     "aarch64-darwin"
    "i686-linux"
    "armv6l-linux"
    "armv7l-linux"
    "riscv64-linux"
    "powerpc64le-linux"
  ];

  pkgsFor = system: import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  systems = builtins.filter (system:
    let eval = builtins.tryEval (pkgsFor system).flutter.meta.available;
    in eval.success && eval.value
  ) allSystems;
in {
  forAllSystems = f:
    nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = pkgsFor system;
        flutter = pkgs.flutter;
      in f pkgs flutter);
}
