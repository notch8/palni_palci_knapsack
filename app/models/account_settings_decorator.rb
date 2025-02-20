# frozen_string_literal: true

# OVERRIDE HYKU 6.0.0 to Disable Some Settings (until ga4 is complete) and to update default contact emails
module AccountSettingsDecorator
  def self.prepended(_base)
    # Disable specific settings
    Account.all_settings[:analytics][:disabled] = true
    Account.all_settings[:analytics_reporting][:disabled] = true
    Account.all_settings[:batch_email_notifications][:disabled] = true
    Account.all_settings[:depositor_email_notifications][:disabled] = true
    Account.all_settings[:user_analytics][:disabled] = true

    # Update default values for contact emails
    Account.all_settings[:contact_email][:default] = 'consortial-ir@palci.org'
    Account.all_settings[:contact_email_to][:default] = 'consortial-ir@palci.org'
  end
end

AccountSettings.prepend AccountSettingsDecorator
