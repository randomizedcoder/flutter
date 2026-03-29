{ pkgs, flutter }:
let
  shellFragments = {
    flutterServer = builtins.readFile ../shell-fragments/flutter-server.sh;
    copyToWorkDir = builtins.readFile ../shell-fragments/copy-to-work-dir.sh;
  };
in {
  dart-analyze = import ./dart-analyze.nix { inherit pkgs flutter shellFragments; };
  dart-code-linter = import ./dart-code-linter.nix { inherit pkgs flutter shellFragments; };
  dart-format-check = import ./dart-format-check.nix { inherit pkgs flutter; };
  flutter-analyze = import ./flutter-analyze.nix { inherit pkgs flutter shellFragments; };
  nix-test = import ./nix-test.nix { inherit pkgs flutter; };
  smoke-test = import ./smoke-test.nix { inherit pkgs flutter shellFragments; };
}
