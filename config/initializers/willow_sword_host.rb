# frozen_string_literal: true

# after_initialize so willow_sword's own initializer, which defaults these to off, cannot run after ours.
Rails.application.config.after_initialize do
  WillowSword.setup do |config|
    config.sword_host_header = 'X-Sword-Host'
    config.sword_allowed_hosts = ENV.fetch('SWORD_ALLOWED_HOSTS', '').split(',').map(&:strip).reject(&:empty?)
  end
end
