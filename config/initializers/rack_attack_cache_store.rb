# frozen_string_literal: true

# Rails.cache flips per-tenant (Account#setup_tenant_cache); pin Rack::Attack to Redis so it can't get stuck on the EFS FileStore variant (Errno::ESTALE under load).
if ENV['RAILS_CACHE_STORE_URL'].to_s.start_with?('redis')
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['RAILS_CACHE_STORE_URL'])
end
