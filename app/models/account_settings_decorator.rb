# frozen_string_literal: true

# OVERRIDE HYKU 6.0.0 to conditionally disable settings based on environment and to update default contact emails.
module AccountSettingsDecorator
  def self.prepended(_base)
    # Update default values for contact emails
    Account.all_settings[:contact_email][:default] = 'consortial-ir@palci.org'
    Account.all_settings[:contact_email_to][:default] = 'consortial-ir@palci.org'

    # Check environment variable to determine if features should be disabled
    # Default to disabled in production, enabled elsewhere
    disable_features = ENV.fetch('DISABLE_ANALYTICS_FEATURES', Rails.env.production?.to_s) == 'true'

    return unless disable_features
    Account.all_settings[:analytics][:disabled] = true
    Account.all_settings[:analytics_reporting][:disabled] = true
    Account.all_settings[:batch_email_notifications][:disabled] = true
    Account.all_settings[:depositor_email_notifications][:disabled] = true
  end
end

AccountSettings.prepend AccountSettingsDecorator
