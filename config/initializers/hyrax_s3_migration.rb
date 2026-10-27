# frozen_string_literal: true

# TEMPORARY(s3-migration): remove once the Hyku pin includes samvera/hyku#3412 (it ships this scope initializer),
# together with every other file carrying this tag.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

# Keeps the manifests written by Hyrax's S3 migration tasks (hyrax:migrate:files_to_s3 and friends)
# per tenant, so quarantine and rollback only touch the current tenant's files.
Rails.application.config.to_prepare do
  Hyrax::S3Migration.scope_provider = -> { Site.account&.cname } if defined?(Hyrax::S3Migration)
end
