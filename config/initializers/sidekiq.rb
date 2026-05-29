# frozen_string_literal: true

Sidekiq.configure_server { |c| c.redis = { url: ENV.fetch('REDIS_URL') } }
Sidekiq.configure_client { |c| c.redis = { url: ENV.fetch('REDIS_URL') } }
