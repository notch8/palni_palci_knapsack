# frozen_string_literal: true

# OVERRIDE Add SuperAdmin Settings for
Account.superadmin_settings = %i[
  analytics_provider
  contact_email
  file_acl
  file_size_limit
  oai_prefix
  oai_sample_identifier
  s3_bucket
  user_analytics
].freeze

# TODO: Does redeclaring this work?  We'll want to write a test for this.
Account.setting :contact_email, type: 'string', default: 'consortial-ir@palci.org'
Account.setting :contact_email_to, type: 'string', default: 'consortial-ir@palci.org'
