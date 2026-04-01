{
  description = "C++ static analysis tooling for the Flutter repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, git-hooks-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Pin to the same LLVM version for all clang-based tools
        llvmPackages = pkgs.llvmPackages_18;
        clang-tools = llvmPackages.clang-tools;

        # Analysis tool set
        analysisTools = [
          clang-tools
          pkgs.cppcheck
          pkgs.include-what-you-use
          pkgs.flawfinder
          pkgs.shellcheck
        ];

        clangTidyConfig = ./nix/clang-tidy-expanded.yaml;

        # Helper to wrap scripts with Nix-provided tools on PATH
        mkScript = name: src:
          pkgs.writeShellScriptBin "flutter-${name}" ''
            export FLUTTER_REPO_ROOT="''${FLUTTER_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
            export CLANG_TIDY_CONFIG="''${CLANG_TIDY_CONFIG:-${clangTidyConfig}}"
            export PATH="${pkgs.lib.makeBinPath analysisTools}:$PATH"
            ${builtins.readFile src}
          '';

        scripts = {
          find-cpp-files       = mkScript "find-cpp-files"       ./nix/scripts/find-cpp-files.sh;
          gen-compile-commands = mkScript "gen-compile-commands"  ./nix/scripts/generate-compile-commands.sh;
          clang-tidy           = mkScript "clang-tidy"           ./nix/scripts/run-clang-tidy.sh;
          clang-format         = mkScript "clang-format"         ./nix/scripts/run-clang-format.sh;
          cppcheck             = mkScript "cppcheck"             ./nix/scripts/run-cppcheck.sh;
          iwyu                 = mkScript "iwyu"                 ./nix/scripts/run-iwyu.sh;
          flawfinder           = mkScript "flawfinder"           ./nix/scripts/run-flawfinder.sh;
          shellcheck           = mkScript "shellcheck"           ./nix/scripts/run-shellcheck.sh;
          analyze-all          = mkScript "analyze-all"          ./nix/scripts/run-all.sh;
        };

        scriptPackages = builtins.attrValues scripts;

        # Pre-commit hooks (fast tools only)
        preCommitHooks = git-hooks-nix.lib.${system}.run {
          src = ./.;
          hooks = {
            clang-format = {
              enable = true;
              types_or = [ "c" "c++" ];
            };
            flawfinder = {
              enable = true;
              entry = "${pkgs.flawfinder}/bin/flawfinder --minlevel=2 --error-level=3";
              types_or = [ "c" "c++" ];
            };
            shellcheck = {
              enable = true;
            };
          };
        };

      in {
        checks = {
          pre-commit-check = preCommitHooks;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = analysisTools ++ scriptPackages;

          shellHook = ''
            export FLUTTER_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            export CLANG_TIDY_CONFIG="${clangTidyConfig}"
            ${preCommitHooks.shellHook}
            echo "Flutter C++ static analysis shell"
            echo "Available commands: flutter-find-cpp-files, flutter-gen-compile-commands,"
            echo "  flutter-clang-tidy, flutter-clang-format, flutter-cppcheck,"
            echo "  flutter-iwyu, flutter-flawfinder, flutter-shellcheck, flutter-analyze-all"
          '';
        };
      }
    );
}
