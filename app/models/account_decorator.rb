# frozen_string_literal: true

# OVERRIDE Add SuperAdmin Settings for
Account.superadmin_settings = %i[
  analytics
  analytics_provider
  batch_email_notifications
  bulkrax_field_mappings
  contact_email
  depositor_email_notifications
  file_acl
  file_size_limit
  oai_prefix
  oai_sample_identifier
  s3_bucket
].freeze
