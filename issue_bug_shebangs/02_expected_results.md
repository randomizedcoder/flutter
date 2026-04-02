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
