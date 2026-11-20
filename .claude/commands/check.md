---
description: Run the plugin's full local quality suite (unit tests, frontend unit tests, syntax)
---
Run the three checks CI runs on every pull request, from the repository root. They need Docker and the image `openproject/openproject:17.9.1`.

```bash
bin/test
bin/test-frontend
bin/check-syntax
```

Report each result: the run and failure counts of `bin/test`, the pass and fail counts of `bin/test-frontend`, and whether `bin/check-syntax` printed `syntax ok`. On a failure, show the failing test or file and stop; do not change tests to make them pass.
