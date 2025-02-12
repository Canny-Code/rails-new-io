# syntax = docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libsqlite3-0 \
    build-essential libssl-dev git pkg-config python-is-python3 libgmp-dev ca-certificates gnupg xz-utils \
    libffi-dev libyaml-dev libreadline-dev zlib1g-dev libncurses5-dev libgdbm-dev \
    libc6-dev vim && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

FROM base AS nodejs

# Install Node.js and Yarn
ARG NODE_VERSION=22.3.0
ARG YARN_VERSION=4.5.3
ENV PATH=/usr/local/node/bin:/usr/local/bin:$PATH

RUN case "$(dpkg --print-architecture)" in \
      amd64) ARCH='x64' ;; \
      arm64) ARCH='arm64' ;; \
      *) echo "Unsupported architecture"; exit 1 ;; \
    esac \
    && curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz | tar -xJ -C /usr/local --strip-components=1 \
    && corepack enable \
    && corepack prepare yarn@4.5.3 --activate

# Verify Yarn installation
RUN yarn --version

FROM nodejs AS build

# Copy package files first
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn/releases/ ./.yarn/releases/

# Now run yarn install
RUN yarn install --immutable

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local build.nokogiri --use-system-libraries && \
    bundle config build.msgpack --with-cflags="-O2" && \
    bundle install --jobs 4 --retry 5 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN RAILS_ENV=production RAILS_BUILD=1 SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

RUN rm -rf node_modules

# Final stage for app image
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /var/lib/rails-new-io/workspaces && \
    chown -R rails:rails /rails /var/lib/rails-new-io && \
    chmod -R 755 /rails /var/lib/rails-new-io && \
    chown -R rails:rails db log storage tmp /usr/local/bundle

USER rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
