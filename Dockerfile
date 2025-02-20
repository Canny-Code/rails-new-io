# syntax = docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.1

FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Install base packages and build dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libsqlite3-0 \
    build-essential libssl-dev git pkg-config python-is-python3 libgmp-dev ca-certificates gnupg xz-utils \
    libffi-dev libyaml-dev libreadline-dev zlib1g-dev libncurses5-dev libgdbm-dev \
    libc6-dev vim sudo \
    # Additional build dependencies for Ruby
    autoconf bison rustc patch gawk \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Update RubyGems and install the correct Bundler version
# This ensures we only have Bundler 2.6.3 (which comes with RubyGems 3.6.3)
RUN gem uninstall -i /usr/local/lib/ruby/gems/3.4.0 bundler && \
    gem update --system 3.6.3

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_PATH="/usr/local/bundle"

FROM base AS nodejs

# Install Node.js and Yarn
ARG NODE_VERSION=23.7.0
ARG YARN_VERSION=4.6.0
ENV PATH=/usr/local/bin:$PATH

RUN case "$(dpkg --print-architecture)" in \
      amd64) ARCH='x64' ;; \
      arm64) ARCH='arm64' ;; \
      *) echo "Unsupported architecture"; exit 1 ;; \
    esac \
    && curl -v -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" | tar -xJ -C /usr/local --strip-components=1 \
    && npm install -g npm@latest \
    && corepack enable \
    && corepack prepare yarn@${YARN_VERSION} --activate

# Verify Yarn installation
RUN yarn --version

FROM nodejs AS build

# Set build-specific environment variables for the host app (railsnew.io)
ENV BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1"

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

ARG NODE_VERSION=23.7.0

# Set production environment for the host app (railsnew.io)
ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    NODE_VERSION=${NODE_VERSION} \
    PATH=/usr/local/bin:$PATH

# Copy Node.js from nodejs stage
COPY --from=nodejs /usr/local/bin/node /usr/local/bin/
COPY --from=nodejs /usr/local/bin/npm /usr/local/bin/
COPY --from=nodejs /usr/local/bin/npx /usr/local/bin/

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Create the rails user first
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    echo "rails ALL=(ALL) NOPASSWD: /usr/bin/mkdir -p /var/lib/rails-new-io/workspaces, /usr/bin/chown rails\:rails /var/lib/rails-new-io/workspaces" > /etc/sudoers.d/rails && \
    # Create base directories
    mkdir -p /var/lib/rails-new-io/workspaces && \
    mkdir -p /var/lib/rails-new-io/rails-env && \
    chown -R rails:rails /var/lib/rails-new-io && \
    chmod -R 755 /var/lib/rails-new-io && \
    chown -R rails:rails /rails && \
    chmod -R 755 /rails && \
    chown -R rails:rails db log storage tmp /usr/local/bundle

USER rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
