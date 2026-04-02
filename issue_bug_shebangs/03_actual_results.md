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
