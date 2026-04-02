# 4 shell scripts missing required #!/bin/bash shebang; 1 script uses invalid zsh syntax in bash file

## Steps to reproduce

This is a code-level bug found via static analysis (shellcheck SC2148, SC2298). Four `.sh` files in the engine are missing the required `#!/bin/bash` shebang, and one script contains invalid zsh-specific syntax inside a file declared as `#!/bin/bash`.

**Google Shell Style Guide compliance:** The [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) is explicit:
- *"Executables must start with `#!/bin/bash` and minimal flags."*
- *"Bash is the only shell scripting language permitted for executables."*

**Repo-wide consistency:** 34 of 38 `.sh` files in `engine/src/flutter/` already have shebangs (89%). These 4 missing shebangs are clear anomalies. Full inventory:

| # | File | Shebang |
|---|------|---------|
| 1 | `build/install-build-deps-linux-desktop.sh` | `#!/bin/bash` |
| 2 | `ci/analyze.sh` | `#!/bin/bash` |
| 3 | `ci/ban_generated_plugin_registrant_java.sh` | `#!/bin/bash` |
| 4 | `ci/binary_size_treemap.sh` | `#!/bin/bash` |
| 5 | `ci/check_build_configs.sh` | `#!/bin/bash` |
| 6 | `ci/clang_tidy.sh` | `#!/bin/bash` |
| 7 | `ci/format.sh` | `#!/usr/bin/env bash` |
| 8 | `ci/licenses_cpp.sh` | `#!/bin/bash` |
| 9 | `ci/pylint.sh` | `#!/bin/bash` |
| 10 | `ci/test/ban_generated_plugin_registrant_java_test.sh` | `#!/bin/bash` |
| 11 | `examples/glfw_drm/run.sh` | `#!/bin/bash` |
| 12 | `examples/glfw/run.sh` | `#!/bin/bash` |
| 13 | `examples/vulkan_glfw/run.sh` | `#!/bin/bash` |
| 14 | `lib/web_ui/dev/web_engine_analysis.sh` | `#!/bin/bash` |
| 15 | **`shell/platform/darwin/find-undocumented-ios.sh`** | **MISSING** |
| 16 | `shell/platform/fuchsia/runtime/dart/utils/run_vmservice_object_tests.sh` | `#!/boot/bin/sh` *(correct — runs on Fuchsia device, which has no `/bin/bash`)* |
| 17 | `testing/analyze_core_dump.sh` | `#!/bin/bash` |
| 18 | `testing/benchmark/generate_metrics.sh` | `#!/bin/bash` |
| 19 | `testing/benchmark/upload_metrics.sh` | `#!/bin/bash` |
| 20 | `testing/dart/run_test.sh` | `#!/bin/bash` |
| 21 | `testing/ios_scenario_app/run_ios_tests.sh` | `#!/bin/bash` |
| 22 | `testing/run_tests.sh` | `#!/bin/bash` |
| 23 | **`testing/sanitizer_suppressions.sh`** | **MISSING** |
| 24 | `tools/android_sdk/create_cipd_packages.sh` | `#!/bin/bash` |
| 25 | `tools/cipd/malioc/generate.sh` | `#!/bin/bash` |
| 26 | `tools/engine_roll_pr_desc.sh` | `#!/bin/bash` |
| 27 | `tools/find_pubspecs_to_workspacify.sh` | `#!/bin/bash` |
| 28 | `tools/fuchsia/devshell/branch_from_fuchsia.sh` | `#!/bin/bash` |
| 29 | `tools/fuchsia/devshell/build_and_copy_to_fuchsia.sh` | `#!/bin/bash` |
| 30 | `tools/fuchsia/devshell/checkout_fuchsia_revision.sh` | `#!/bin/bash` |
| 31 | `tools/fuchsia/devshell/lib/vars.sh` | `#!/bin/bash` |
| 32 | `tools/fuchsia/devshell/run_integration_test.sh` | `#!/bin/bash` |
| 33 | `tools/fuchsia/devshell/run_unit_tests.sh` | `#!/bin/bash` |
| 34 | `tools/fuchsia/devshell/test/test_build_and_copy_to_fuchsia.sh` | `#!/bin/bash` |
| 35 | `tools/fuchsia/devshell/test/test_run_unit_tests.sh` | `#!/bin/bash` |
| 36 | **`tools/vscode_workspace/merge.sh`** | **MISSING** |
| 37 | **`tools/vscode_workspace/refresh.sh`** | **MISSING** |
| 38 | `tools/yapf.sh` | `#!/usr/bin/env bash` |

**Summary:** 31 use `#!/bin/bash`, 2 use `#!/usr/bin/env bash`, 1 uses `#!/boot/bin/sh` (correct — this script runs on a Fuchsia device where `/boot/bin/sh` is the standard shell path; bash is not available on Fuchsia), **4 are missing** (bolded above).

**Why this matters:** Without a shebang, the behavior of a directly-executed script depends on the parent shell or the kernel's `exec()` default interpreter — which may not be bash. On some systems this defaults to `/bin/sh` (which may be dash, ash, or another minimal shell), causing bash-specific features to fail silently or produce confusing errors.

**Issue 1 — Missing shebangs (shellcheck SC2148):**

| File | Execution | Shell features | Fix |
|------|-----------|---------------|-----|
| `shell/platform/darwin/find-undocumented-ios.sh` | Direct | POSIX-only | Add `#!/bin/bash` |
| `testing/sanitizer_suppressions.sh` | Sourced | Bash-specific (`${BASH_SOURCE[0]}`) | Add `#!/bin/bash` (see note below) |
| `tools/vscode_workspace/merge.sh` | Direct | POSIX-compatible | Add `#!/bin/bash` |
| `tools/vscode_workspace/refresh.sh` | Direct | POSIX-compatible | Add `#!/bin/bash` |

> **Note on sourced files:** One might argue `sanitizer_suppressions.sh` doesn't need a shebang because it's sourced (`. script.sh`), not executed directly. However, shellcheck uses the shebang to determine which linting rules to apply — without it, the file is effectively **un-lintable** in CI. Adding `#!/bin/bash` ensures static analysis tools can validate the file and it stays healthy over time.

**Issue 2 — Zsh syntax in bash script (shellcheck SC2298/SC2296):**

`tools/fuchsia/devshell/lib/vars.sh` has `#!/bin/bash` but contains zsh-specific syntax:

```bash
#!/bin/bash
if [[ -n "${ZSH_VERSION:-}" ]]; then
  devshell_lib_dir=${${(%):-%x}:a:h}    # <-- zsh-only: nested expansion, prompt expansion
else
  devshell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
fi
```

Shellcheck flags `${${(%):-%x}:a:h}` as invalid bash (SC2298: nested `${${...}}`, SC2296: expansion starting with `(`). The code is functionally correct — the zsh branch only executes under zsh — but it violates the Google Shell Style Guide's rule that *"Bash is the only shell scripting language permitted."*

**Recommended fix:** Replace the entire zsh/bash if-else with a single portable line:
```bash
readonly devshell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
```
`${BASH_SOURCE[0]:-$0}` is a common idiom that works in both bash and zsh without triggering shellcheck errors. This eliminates the zsh-specific syntax entirely while preserving cross-shell compatibility.

**Steps to reproduce:**

1. Run shellcheck on all `.sh` files in `engine/src/flutter/`:
   ```
   find engine/src/flutter -name "*.sh" -exec shellcheck --severity=warning {} +
   ```
2. Observe SC2148 (missing shebang) on 4 files and SC2298/SC2296 on `vars.sh`.

**Existing issue search**: We searched for related issues and PRs before filing:

Related issues:
- #16130 — "Install script uses absolute path for shebangs" — closed (fixed by PR #16135). NixOS user reported `#!/bin/bash` doesn't work on NixOS; fix changed to `#!/usr/bin/env bash`. **Precedent: shebang issues have been accepted and fixed before.**
- #68413 — "[flutter_tools] shell check bash scripts in tool" — closed. Proposed applying shellcheck to `xcode_backend.sh` and `macos_assemble.sh`. Shows maintainer awareness of shellcheck.
- #148817 — "Shebang line in Flutter script causes issues on macOS Monterey" — closed. Different shebang problem (wrong path), not missing shebangs.

Related PRs:
- PR #408 — "Moar shebang." — merged (2015). Added shebang to make a script directly executable. **Exact same class of fix we're proposing.**
- PR #16135 — "Fix absolute shebangs in install scripts" — merged (2018). Fixed #16130.
- PR #30456 — "make shellcheck (linter) changes to bin/flutter bash script" — merged (2019). Applied shellcheck fixes to `bin/flutter`. **Precedent: shellcheck-driven fixes are accepted.**

No existing issues track these specific 4 missing shebangs or the zsh syntax in `vars.sh`.

**Note on NixOS:** Issue #16130 reported that `#!/bin/bash` doesn't work on NixOS because `/bin/bash` doesn't exist. However, NixOS has a built-in mechanism called [`patchShebangs`](https://nixos.org/manual/nixpkgs/stable/#ssec-setup-hook-patch-shebangs) that automatically rewrites shebangs (e.g., `#!/bin/bash` → `/nix/store/...-bash-5.2/bin/bash`) during the build's fixup phase. This means having a shebang is *more* important on NixOS, not less — `patchShebangs` can only fix what's there. A file with no shebang at all cannot be patched and will fall back to unpredictable behavior.

## Expected results

**Issue 1 — Missing shebangs:** All 4 files should have `#!/bin/bash` as the first line, matching the 34 other `.sh` files in the engine and complying with the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): *"Executables must start with `#!/bin/bash`."*

Fix for each file — add as the first line (before the copyright comment):
```bash
#!/bin/bash
```

**Issue 2 — Zsh syntax:** Replace the entire zsh/bash if-else block with a single portable line:

```bash
readonly devshell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
```

`${BASH_SOURCE[0]:-$0}` works in both bash and zsh without zsh-specific syntax, eliminating the shellcheck errors while preserving cross-shell compatibility. This is strictly compliant with the Google Shell Style Guide (*"Bash is the only shell scripting language permitted"*) and avoids the "clever" polyglot pattern that could break in edge cases.

## Actual results

**Missing shebangs:** When a `.sh` file without a shebang is executed directly (e.g., `./find-undocumented-ios.sh`), the kernel's `exec()` falls back to the system default interpreter:

```
./script.sh
    │
    ▼
kernel exec() reads first bytes
    │
    ├── "#!" found → use specified interpreter (e.g., /bin/bash)  ✓ deterministic
    │
    └── no "#!" found → fall back to /bin/sh                      ✗ varies by distro
                │
                ├── Debian/Ubuntu: /bin/sh → dash (no ${BASH_SOURCE}, arrays, [[ ]])
                ├── Alpine/BusyBox: /bin/sh → ash (similar limitations)
                └── Some distros: /bin/sh → bash (happens to work, masking the bug)
```

This means the same script may work on one developer's machine and fail on another, depending on what `/bin/sh` points to. The failure is silent or produces confusing error messages unrelated to the actual cause (missing shebang).

**Zsh syntax in bash file:** Shellcheck correctly identifies `${${(%):-%x}:a:h}` as invalid bash syntax. While this branch only executes under zsh (guarded by `$ZSH_VERSION` check), the `#!/bin/bash` shebang declares this as a bash script, creating a contradiction.

## Code sample

<details open><summary>Code sample</summary>

**Missing shebang example** — `find-undocumented-ios.sh` (currently):
```bash
# Copyright 2013 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
doxygen Doxyfile 2>&1 | grep "not documented"
```

**Fix** — add shebang as first line:
```bash
#!/bin/bash
# Copyright 2013 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
doxygen Doxyfile 2>&1 | grep "not documented"
```

**Zsh syntax issue** — `devshell/lib/vars.sh` (lines 7-11):
```bash
#!/bin/bash
# ...
if [[ -n "${ZSH_VERSION:-}" ]]; then
  devshell_lib_dir=${${(%):-%x}:a:h}    # zsh-only syntax in a #!/bin/bash file
else
  devshell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
fi
```

**Fix** — replace the entire if-else with a single portable line:
```bash
#!/bin/bash
# ...
readonly devshell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
```

`${BASH_SOURCE[0]:-$0}` works in both bash and zsh without needing zsh-specific syntax. This eliminates the shellcheck errors and complies with the Google Shell Style Guide.

</details>

## Screenshots / Video demonstration

<details open>
<summary>Screenshots / Video demonstration</summary>

Not applicable — this is a shell script issue found by static analysis, not a visual issue.

</details>

## Logs

<details open><summary>Logs</summary>

Static analysis output:

```console
$ shellcheck --severity=warning engine/src/flutter/shell/platform/darwin/find-undocumented-ios.sh
Line 1:
# Copyright 2013 The Flutter Authors. All rights reserved.
^-- SC2148 (error): Tips depend on target shell and target shell was not specified.
    Add a shebang, a 'shell' directive, or a '.shellcheckrc' file.

$ shellcheck --severity=warning engine/src/flutter/testing/sanitizer_suppressions.sh
Line 1:
# Copyright 2013 The Flutter Authors. All rights reserved.
^-- SC2148 (error): Tips depend on target shell and target shell was not specified.

$ shellcheck --severity=warning engine/src/flutter/tools/vscode_workspace/merge.sh
^-- SC2148 (error): Tips depend on target shell and target shell was not specified.

$ shellcheck --severity=warning engine/src/flutter/tools/vscode_workspace/refresh.sh
^-- SC2148 (error): Tips depend on target shell and target shell was not specified.

$ shellcheck --severity=warning engine/src/flutter/tools/fuchsia/devshell/lib/vars.sh
Line 8:
  devshell_lib_dir=${${(%):-%x}:a:h}
                    ^-- SC2296 (error): Parameter expansions can't start with (.
                   ^-- SC2298 (error): ${${..}} is invalid. For expansion, use ${var}.
```

Repo-wide shebang compliance:
- **34 of 38** `.sh` files have shebangs (89%)
- 31 use `#!/bin/bash`, 2 use `#!/usr/bin/env bash`, 1 uses `#!/boot/bin/sh`
- These 4 files are the only anomalies

Reference:
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): *"Executables must start with `#!/bin/bash` and minimal flags."*

</details>

## Flutter Doctor output

<details open><summary>Doctor output</summary>

```console
[!] Flutter (Channel [user-branch], 3.43.0-1.0.pre-391, on NixOS 26.05 (Yarara) 6.19.9, locale en_US.UTF-8) [51ms]
    ! Flutter version 3.43.0-1.0.pre-391 on channel [user-branch] at /home/das/Downloads/flutter
      Currently on an unknown channel. Run `flutter channel` to switch to an official channel.
      If that doesn't fix the issue, reinstall Flutter by following instructions at https://flutter.dev/setup.
    • Framework revision c589dfffda (16 hours ago), 2026-03-31 22:16:58 -0400
    • Engine revision be1e70f0a8
    • Dart version 3.12.0 (build 3.12.0-304.0.dev)
    • DevTools version 2.57.0-dev.0

[!] Android toolchain - develop for Android devices (Android SDK version 31.0.0)
    • Android SDK at /home/das/Android/Sdk

[✓] Chrome - develop for the web
    • CHROME_EXECUTABLE = /nix/store/5fyi5df2lfhmvjgvlkdm5b46rbwxibsy-google-chrome-146.0.7680.153/bin/google-chrome-stable

[✗] Linux toolchain - develop for Linux desktop
    ✗ clang++ is required for Linux development.
    ✗ CMake is required for Linux development.
    ✗ ninja is required for Linux development.

[✓] Connected device (2 available)
    • Linux (desktop) • linux  • linux-x64      • NixOS 26.05 (Yarara) 6.19.9
    • Chrome (web)    • chrome • web-javascript • Google Chrome 146.0.7680.153

[✓] Network resources
    • All expected network resources are available.

! Doctor found issues in 3 categories.
```

</details>
