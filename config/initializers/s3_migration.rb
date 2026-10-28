# frozen_string_literal: true

# One bucket serves every tenant, so keep each tenant's migration manifest under its own cname; quarantine,
# rollback and purge then only touch the current tenant's files.
Rails.application.config.to_prepare do
  S3Migration.scope_provider = -> { Site.account&.cname } if defined?(S3Migration)
end
