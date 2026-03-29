#
# Flutter Hello World — Nix flake
#
# Getting started:
#   cd examples/hello_world
#   nix develop                      — dev shell with pinned Flutter + Dart
#   flutter run -d chrome            — run the app
#   flutter test                     — run tests
#
# Checks (run from examples/hello_world/):
#   nix flake check                  — verify all Nix expressions evaluate
#   nix run .#dart-analyze           — dart analyze in isolated temp dir
#   nix run .#flutter-analyze        — flutter analyze in isolated temp dir
#   nix run .#dart-format-check      — verify dart format compliance
#
# Utilities:
#   nix fmt                          — format Dart files in-place (page width 100)
#
{
  description = "Dev shell and analysis checks for the Flutter Hello World example";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    lib = import ../nix/lib.nix { inherit nixpkgs; };
    inherit (lib) forAllSystems;

    # Build shellFragments with PROJECT_NAME baked in for the shared scripts.
    mkShellFragments = ''export PROJECT_NAME="hello_world"'' + "\n"
      + builtins.readFile ../nix/shell-fragments/copy-to-work-dir.sh;
    flutterServerFragment = builtins.readFile ../nix/shell-fragments/flutter-server.sh;

    allPackages = forAllSystems (pkgs: flutter:
      let
        shellFragments = {
          copyToWorkDir = mkShellFragments;
          flutterServer = flutterServerFragment;
        };
      in {
        dart-analyze = import ../nix/packages/dart-analyze.nix {
          inherit pkgs flutter shellFragments;
        };
        flutter-analyze = import ../nix/packages/flutter-analyze.nix {
          inherit pkgs flutter shellFragments;
        };
        dart-format-check = import ../nix/packages/dart-format-check.nix {
          inherit pkgs flutter;
          projectName = "hello_world";
        };
      }
    );
  in {
    packages = allPackages;

    # `nix fmt` formats Dart files in-place at page width 100.
    formatter = forAllSystems (pkgs: flutter:
      pkgs.writeShellApplication {
        name = "dart-format";
        runtimeInputs = [ flutter ];
        text = ''
          dart format --page-width=100 "$@"
        '';
      }
    );

    # `nix flake check` builds every check script, verifying that all Nix
    # expressions evaluate correctly and all dependencies resolve.
    checks = forAllSystems (pkgs: flutter:
      let packages = allPackages.${pkgs.stdenv.hostPlatform.system}; in {
        dart-analyze = packages.dart-analyze;
        dart-format-check = packages.dart-format-check;
        flutter-analyze = packages.flutter-analyze;
      }
    );

    devShells = forAllSystems (pkgs: flutter: {
      default = import ../nix/shell.nix {
        inherit pkgs flutter;
        name = "hello-world";
        helpText = ''
          echo "Run the example:"
          echo "  flutter run -d chrome   # web"
          echo "  flutter run             # default device"
          echo ""
          echo "Run tests:"
          echo "  flutter test"
        '';
      };
    });
  };
}
