---
description: Run the Ruby unit tests, optionally one file
argument-hint: "[test/<file>_test.rb]"
---
Run the Ruby unit tests from the repository root. They need Docker, no Rails and no database.

With no argument, run all of them:

```bash
bin/test
```

With a file in $ARGUMENTS, run only that file with the same image and paths `bin/test` uses:

```bash
docker run --rm -v "$PWD":/plugin:ro -w /plugin --entrypoint ruby openproject/openproject:17.9.1 -Ilib -Itest $ARGUMENTS
```

Report the run, failure and error counts and the first failure in full.
