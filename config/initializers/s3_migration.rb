# frozen_string_literal: true

# One bucket serves every tenant, so each tenant's manifest lives under its own cname. With no tenant the gem
# would match every tenant's manifests, and an unscoped purge would reach them all, so refuse instead.
Rails.application.config.to_prepare do
  next unless defined?(S3Migration)

  S3Migration.scope_provider = lambda do
    Site.account&.cname.presence ||
      raise(ArgumentError, 'run s3_migration inside a tenant: use rake hyku:s3_migration:<step> with tenants=')
  end
end
