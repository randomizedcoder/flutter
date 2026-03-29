{ pkgs, flutter, name, helpText ? "" }:
pkgs.mkShell {
  packages = [
    flutter
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.unzip
    pkgs.which
  ];

  shellHook = ''
    export PS1="(${name}) ''${PS1:-\w\$ }"

    echo "Flutter: $(flutter --version | head -n1 || true)"
    echo "Dart:    $(dart --version | head -n1 || true)"
    echo ""
    ${helpText}
  '';
}
