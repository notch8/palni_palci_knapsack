# frozen_string_literal: true

# OVERRIDE Hyku (198f4950), backporting v7.2.1: in multitenant mode tenant settings load in
# Account#switch! instead of on every Account load, so loading another tenant's account
# (e.g. shared search) can't overwrite them
module AccountDecorator
  private

  def initialize_settings
    return super unless Hyku.multitenant?
    return true unless self.class.column_names.include?('settings')
    set_smtp_settings
  end
end

# OVERRIDE Hyku (198f4950), backporting v7.2.1: load tenant settings on every tenant switch
module AccountSwitchDecorator
  def switch!
    super
    reload_library_config if self.class.column_names.include?('settings')
  end
end

Account.include(AccountDecorator)
Account.prepend(AccountSwitchDecorator)
