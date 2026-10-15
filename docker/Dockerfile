# Development image: OpenProject with this plugin installed.
# Build from the repository root: docker build -f docker/Dockerfile -t openproject-thematiq:dev .
# See https://www.openproject.org/docs/installation-and-operations/installation/docker/ ("Using this container with custom plugins").
# Pinned to the release the plugin is tested on. The :17 tag moves with every 17.x release.
FROM openproject/openproject:17.9.1@sha256:1931b0bcdceb07c38293c3afafa7fe3da09e9fa76144604b92813d6c6d05c695

COPY . /app/custom-plugins/openproject-thematiq
COPY docker/Gemfile.plugins /app/Gemfile.plugins

RUN bundle config unset deployment && bundle install && bundle config set deployment 'true'

# OpenProject's docs also run ./docker/prod/setup/precompile-assets.sh here. On this image that step
# does nothing for a plugin without a frontend, so the plugin inlines its CSS through a view hook instead.
