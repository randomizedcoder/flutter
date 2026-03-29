#
# Flutter Web Telemetry — Nix flake
#
# Getting started:
#   cd examples/web_telemetry
#   nix develop                      — dev shell with pinned Flutter + Dart
#   flutter run -d chrome            — run the app (debug mode)
#   flutter run -d chrome --release  — run the app (release mode)
#
# Checks (run from examples/web_telemetry/):
#   nix flake check                  — verify all Nix expressions evaluate
#   nix run .#dart-analyze           — dart analyze in isolated temp dir
#   nix run .#flutter-analyze        — flutter analyze in isolated temp dir
#   nix run .#dart-code-linter       — dart_code_linter (metrics, unused code, etc.)
#   nix run .#dart-format-check      — verify dart format compliance
#   nix run .#smoke-test             — unit tests + analysis + web build + HTTP check
#
# Utilities:
#   nix fmt                          — format Dart files in-place (page width 100)
#   nix run .#nix-test               — comprehensive test of all nix targets (for flake developers)
#
{
  description = "Dev shell, smoke test, and formatting checks for the Flutter Web Telemetry example";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    lib = import ../nix/lib.nix { inherit nixpkgs; };
    inherit (lib) forAllSystems;

    # Build shellFragments with PROJECT_NAME baked in for the shared scripts.
    mkShellFragments = ''export PROJECT_NAME="web_telemetry"'' + "\n"
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
        dart-code-linter = import ../nix/packages/dart-code-linter.nix {
          inherit pkgs flutter shellFragments;
        };
        dart-format-check = import ../nix/packages/dart-format-check.nix {
          inherit pkgs flutter;
          projectName = "web_telemetry";
        };
        nix-test = import ./nix/packages/nix-test.nix {
          inherit pkgs flutter;
        };
        smoke-test = import ./nix/packages/smoke-test.nix {
          inherit pkgs flutter shellFragments;
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
    # expressions evaluate correctly and all dependencies resolve. This
    # catches import errors, missing arguments, and broken derivations.
    #
    # Note: these checks validate that the *scripts* build, not that the
    # analysis tools pass — the scripts need network access to run
    # `flutter pub get`, which the Nix build sandbox blocks. To actually
    # execute the checks, use `nix run .#dart-analyze` (etc.) or
    # `nix run .#nix-test` for a comprehensive run of all targets.
    checks = forAllSystems (pkgs: flutter:
      let packages = allPackages.${pkgs.stdenv.hostPlatform.system}; in {
        dart-analyze = packages.dart-analyze;
        dart-code-linter = packages.dart-code-linter;
        dart-format-check = packages.dart-format-check;
        flutter-analyze = packages.flutter-analyze;
      }
    );

    devShells = forAllSystems (pkgs: flutter: {
      default = import ../nix/shell.nix {
        inherit pkgs flutter;
        name = "web-telemetry";
        helpText = ''
          echo "Run the example:"
          echo "  flutter run -d chrome            # debug mode"
          echo "  flutter run -d chrome --release  # release mode (batched frame timings)"
          echo ""
          echo "Run tests:"
          echo "  flutter test"
        '';
      };
    });
  };
}
