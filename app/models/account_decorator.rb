# frozen_string_literal: true

# OVERRIDE HYKU 6.0.0 to Add SuperAdmin Settings
Account.superadmin_settings = %i[
  analytics
  analytics_reporting
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
  user_analytics
].freeze

# some settings available to superadmin have been disabled in the AccountSettingsDecorator until the completion of GA4

# analytics
# analytics_reporting
# batch_email_notifications
# depositor_email_notifications
# user_analytics
