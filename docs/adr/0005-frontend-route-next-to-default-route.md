# 5. A frontend route next to the default route, without editing core files

- Status: accepted (decided by the owner)
- Source: [docs/design/frontend-build-variant.md](../design/frontend-build-variant.md)

## Context

The plugin reaches most of thematiq's capabilities without a frontend build. A few, such as the icon pack, need code inside OpenProject's Angular bundle. The official image ships a prebuilt frontend, and OpenProject's documented plugin step reuses it, so a plugin's Angular module is never linked.

## Decision

- `docker/Dockerfile` has stages. The default route reuses OpenProject's prebuilt frontend and stays the last stage, so a build without `--target` gives the same image as before.
- A second route, `--target frontend`, rebuilds OpenProject's Angular frontend with the plugin's module in `frontend/module/` linked, in a build stage that is thrown away, and copies only the new bundle, manifest and a stamp `frontend-build.json` into the image.
- Core files are not edited. The build runs core's own steps itself, with the heap from the build argument `THEMATIQ_NODE_MEMORY_MB`.
- At runtime the plugin compares the stamp with its module sources, and the admin page says which route runs and whether the bundle is in step.

## Consequences

- The default route does not change and needs no Node build.
- The frontend route ships a bundle OpenProject did not build, leans on an internal mechanism that can change in any release, and needs several GB of memory to build.
- Each OpenProject release adds a frontend build and an e2e run with `THEMATIQ_E2E_FRONTEND=1` to the upgrade work.
