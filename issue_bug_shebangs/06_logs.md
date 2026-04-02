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
