{ pkgs, flutter, shellFragments }:
pkgs.writeShellApplication {
  name = "dart-analyze";
  runtimeInputs = [ flutter pkgs.coreutils pkgs.gnused ];
  text = shellFragments.copyToWorkDir + ''
    flutter pub get
    dart analyze
  '';
}
