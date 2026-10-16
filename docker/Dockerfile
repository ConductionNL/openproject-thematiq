# Development image: OpenProject with this plugin installed.
# Build from the repository root: docker build -f docker/Dockerfile -t openproject-thematiq:dev .
# See https://www.openproject.org/docs/installation-and-operations/installation/docker/ ("Using this container with custom plugins").
#
# Two routes. Without --target you get the default image, which reuses OpenProject's prebuilt frontend.
# With --target frontend, OpenProject's Angular frontend is rebuilt with the plugin's module in frontend/module
# linked in. See docs/design/frontend-build-variant.md.

# Pinned to the release the plugin is tested on. The :17 tag moves with every 17.x release.
FROM openproject/openproject:17.9.1@sha256:1931b0bcdceb07c38293c3afafa7fe3da09e9fa76144604b92813d6c6d05c695 AS plugin

COPY . /app/custom-plugins/openproject-thematiq
COPY docker/Gemfile.plugins /app/Gemfile.plugins

RUN bundle config unset deployment && bundle install && bundle config set deployment 'true'

# Rebuilds OpenProject's frontend with the plugin's module linked. Only built for --target frontend.
FROM plugin AS frontend-build

# Heap of the Angular build in MB. OpenProject's own build script sets 4096.
ARG THEMATIQ_NODE_MEMORY_MB=6144

# The steps of OpenProject's assets:angular task, with the heap set here instead of in core's npm script.
RUN cd /app/frontend && npm ci --no-audit --no-fund
# The image's schema cache names PostgreSQL classes the null database cannot load. This stage is thrown away,
# so the cache only goes from here, not from the image.
RUN rm -f /app/db/schema_cache.yml \
 && SECRET_KEY_BASE="$(openssl rand -hex 64)" DATABASE_URL=nulldb://db \
    bin/rails openproject:plugins:register_frontend assets:export_locales
RUN rm -rf /app/public/assets/frontend \
 && cd /app/frontend \
 && node --max-old-space-size="${THEMATIQ_NODE_MEMORY_MB}" ./node_modules/@angular/cli/bin/ng build \
      --configuration production --named-chunks --source-map \
 && echo "Peak memory of the frontend build: $(( $(cat /sys/fs/cgroup/memory.peak 2>/dev/null || echo 0) / 1048576 )) MB"
RUN SECRET_KEY_BASE="$(openssl rand -hex 64)" DATABASE_URL=nulldb://db bin/rails assets:rebuild_manifest \
 && ruby /app/custom-plugins/openproject-thematiq/script/stamp-frontend-build.rb

# The frontend route: the default image with the rebuilt frontend in place of OpenProject's.
FROM plugin AS frontend

RUN rm -rf /app/public/assets/frontend
COPY --chown=app:app --from=frontend-build /app/public/assets/frontend /app/public/assets/frontend
COPY --chown=app:app --from=frontend-build /app/config/frontend_assets.manifest.json /app/config/frontend_assets.manifest.json
COPY --chown=app:app --from=frontend-build /app/custom-plugins/openproject-thematiq/frontend-build.json /app/custom-plugins/openproject-thematiq/frontend-build.json

# The default route. It stays the last stage, so a build without --target gives this image.
FROM plugin AS default

# OpenProject's docs also run ./docker/prod/setup/precompile-assets.sh here. On this image that step reuses the
# prebuilt frontend (its manifest is in the image), so the plugin inlines its CSS through a view hook instead.
