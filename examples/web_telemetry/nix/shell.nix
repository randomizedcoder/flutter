{ pkgs, flutter }:
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
    export PS1="(telemetry) ''${PS1:-\w\$ }"

    echo "Flutter: $(flutter --version | head -n1 || true)"
    echo "Dart:    $(dart --version | head -n1 || true)"
    echo ""
    echo "Run the example:"
    echo "  flutter run -d chrome            # debug mode"
    echo "  flutter run -d chrome --release  # release mode (batched frame timings)"
    echo ""
    echo "Run tests:"
    echo "  flutter test"
  '';
}
