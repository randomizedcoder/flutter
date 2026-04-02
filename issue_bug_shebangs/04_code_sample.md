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
