# Per https://www.openproject.org/docs/installation-and-operations/installation/docker/ "Using this container with custom plugins"
FROM openproject/openproject:17
COPY openproject-token_theme /app/custom-plugins/openproject-token_theme
COPY Gemfile.plugins /app/
RUN bundle config unset deployment && bundle install && bundle config set deployment 'true'
RUN ./docker/prod/setup/precompile-assets.sh
