# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Runtime dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libpq5 \
      libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so 2>/dev/null || true && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# ── Build stage ───────────────────────────────────────────────────────────────
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      nodejs \
      npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

RUN bundle exec bootsnap precompile -j 1 --gemfile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production ./bin/rails assets:precompile

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

USER 1000:1000

EXPOSE 3000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
