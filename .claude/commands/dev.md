---
description: Start, follow or stop the local OpenProject with the plugin
argument-hint: "up | logs | down | reset"
---
Use the compose file in `docker/compose.yml`, from the repository root. It serves OpenProject on `http://localhost:8080` (set `THEMATIQ_PORT` for another port). First sign in: `admin` / `admin`.

| $ARGUMENTS | Command |
|---|---|
| `up` (default) | `docker compose -f docker/compose.yml up -d --build` |
| `logs` | `docker compose -f docker/compose.yml logs --tail 200` |
| `down` | `docker compose -f docker/compose.yml down` (keeps the data) |
| `reset` | `docker compose -f docker/compose.yml down -v` (removes the volumes; confirm first) |

The plugin is copied into the image, so after a code change run `up` again to rebuild. To run a rake task inside the instance: `docker compose -f docker/compose.yml exec openproject bash -lc 'cd /app && bundle exec rake thematiq:status'`.
