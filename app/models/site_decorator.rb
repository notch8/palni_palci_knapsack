# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0, backporting v7.2.1: also clear the per-request analytics config
# (Hyrax::AnalyticsDecorator) on every tenant switch
module SiteDecorator
  def reset!
    super
    RequestStore.store.delete(:hyrax_analytics_config)
  end
end

Site.singleton_class.prepend(SiteDecorator)
