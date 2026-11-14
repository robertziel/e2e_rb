# Playwright's image: Node + browsers matching playwright-core 1.65.0, the
# version @e2e-dev/web 0.16 pins. Ruby comes from Ubuntu.
FROM mcr.microsoft.com/playwright:v1.65.0-noble

RUN apt-get update \
 && apt-get install -y --no-install-recommends ruby ruby-dev build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && gem install bundler --no-document

WORKDIR /gem
COPY Gemfile Gemfile.lock* e2e_rb.gemspec ./
COPY lib/e2e_rb/version.rb lib/e2e_rb/version.rb
RUN bundle install

WORKDIR /gem/example
COPY example/package.json example/package-lock.json* ./
RUN npm install --no-audit --no-fund

WORKDIR /gem
COPY . .
