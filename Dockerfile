# The test image: a Ruby (RUBY_VERSION, the CI matrix), Node, and the Chromium build
# that matches the playwright-core the e2e web engine pins (example/package-lock.json),
# with its system libraries. Headless: no X server.
ARG RUBY_VERSION
ARG NODE_IMAGE=node:24.21.0-bookworm-slim
FROM ${NODE_IMAGE} AS node

FROM ruby:${RUBY_VERSION}-slim-bookworm
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && apt-get update \
 && apt-get install -y --no-install-recommends build-essential git \
 && rm -rf /var/lib/apt/lists/*

# BUNDLE_GEMFILE picks the dependency set (Gemfile: Minitest 6; gemfiles/minitest5.gemfile: Minitest 5).
ARG BUNDLE_GEMFILE=Gemfile
ENV BUNDLE_GEMFILE=/gem/${BUNDLE_GEMFILE} PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
WORKDIR /gem
COPY Gemfile Gemfile.lock e2e_rb.gemspec ./
COPY gemfiles gemfiles
COPY lib/e2e_rb/version.rb lib/e2e_rb/version.rb
RUN bundle install

WORKDIR /gem/example
COPY example/package.json example/package-lock.json ./
RUN npm ci --no-audit --no-fund \
 && node_modules/.bin/playwright-core install --with-deps chromium \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /gem
COPY . .
