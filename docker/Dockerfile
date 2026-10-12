# Development image: OpenProject with this plugin installed.
# Build from the repository root: docker build -f docker/Dockerfile -t openproject-thematiq:dev .
# See https://www.openproject.org/docs/installation-and-operations/installation/docker/ ("Using this container with custom plugins").
FROM openproject/openproject:17

COPY . /app/custom-plugins/openproject-thematiq
COPY docker/Gemfile.plugins /app/Gemfile.plugins

RUN bundle config unset deployment && bundle install && bundle config set deployment 'true'

# OpenProject's docs also run ./docker/prod/setup/precompile-assets.sh here. On this image that step
# does nothing for a plugin without a frontend, so the plugin inlines its CSS through a view hook instead.
