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
    libc6-dev vim sudo && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    RAILS_BUILD="1"

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

# Create the rails user first
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    echo "rails ALL=(ALL) NOPASSWD: /usr/bin/mkdir -p /var/lib/rails-new-io/workspaces, /usr/bin/chown rails\:rails /var/lib/rails-new-io/workspaces" > /etc/sudoers.d/rails

# Set up isolated Ruby environment
RUN mkdir -p /var/lib/rails-new-io/rails-env/ruby && \
    cp -r /usr/local/* /var/lib/rails-new-io/rails-env/ruby/ && \
    # Create all isolation directories
    mkdir -p /var/lib/rails-new-io/rails-env/gems/bin && \
    mkdir -p /var/lib/rails-new-io/rails-env/gems/specifications && \
    mkdir -p /var/lib/rails-new-io/rails-env/gems/gems && \
    mkdir -p /var/lib/rails-new-io/rails-env/gems/extensions && \
    mkdir -p /var/lib/rails-new-io/rails-env/bundle && \
    mkdir -p /var/lib/rails-new-io/workspaces && \
    mkdir -p /var/lib/rails-new-io/home && \
    mkdir -p /var/lib/rails-new-io/config && \
    mkdir -p /var/lib/rails-new-io/cache && \
    mkdir -p /var/lib/rails-new-io/data && \
    # Install bundler with minimal env
    PATH=/var/lib/rails-new-io/rails-env/ruby/bin:/usr/local/bin:/usr/bin:/bin \
    GEM_HOME=/var/lib/rails-new-io/rails-env/gems \
    GEM_PATH=/var/lib/rails-new-io/rails-env/gems:/var/lib/rails-new-io/rails-env/ruby/lib/ruby/gems/3.4.0 \
    HOME=/var/lib/rails-new-io/home \
    /var/lib/rails-new-io/rails-env/ruby/bin/gem install bundler -v 2.6.3 && \
    # Install Rails with minimal env
    PATH=/var/lib/rails-new-io/rails-env/ruby/bin:/usr/local/bin:/usr/bin:/bin \
    GEM_HOME=/var/lib/rails-new-io/rails-env/gems \
    GEM_PATH=/var/lib/rails-new-io/rails-env/gems:/var/lib/rails-new-io/rails-env/ruby/lib/ruby/gems/3.4.0 \
    HOME=/var/lib/rails-new-io/home \
    /var/lib/rails-new-io/rails-env/ruby/bin/gem install rails -v 8.0.1 && \
    # Create the rails executable with the correct path and force railties version
    printf '#!/var/lib/rails-new-io/rails-env/ruby/bin/ruby\nrequire "rubygems"\ngem "railties", "8.0.1"  # Force the specific version\nrequire "rails/cli"\n' > /var/lib/rails-new-io/rails-env/gems/bin/rails && \
    chmod +x /var/lib/rails-new-io/rails-env/gems/bin/rails

# Now we can chown everything since the user exists
RUN chown -R rails:rails /var/lib/rails-new-io && \
    chmod -R 755 /var/lib/rails-new-io && \
    chown -R rails:rails /rails && \
    chmod -R 755 /rails && \
    chown -R rails:rails db log storage tmp /usr/local/bundle

USER rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
