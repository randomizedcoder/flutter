{ pkgs, flutter, shellFragments }:
pkgs.writeShellApplication {
  name = "flutter-analyze";
  runtimeInputs = [ flutter pkgs.coreutils pkgs.gnused ];
  text = shellFragments.copyToWorkDir + ''
    flutter pub get
    flutter analyze
  '';
}
