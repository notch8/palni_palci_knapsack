# frozen_string_literal: true

# OVERRIDE Hyrax - Ga4::Base#results calls the GA4 client unconditionally;
# Ga4::Config#account_json_string raises TypeError (File.read(nil)) instead of
# degrading gracefully when GA4 credentials aren't configured for a tenant.
# HYRAX-BACKPORT: samvera/hyrax#7671 - remove once the
# hyrax-webapp pin includes it.
module Hyrax
  module Analytics
    module Ga4
      module BaseDecorator
        def results
          @results ||= Hyrax::Analytics.config.valid? ? Hyrax::Analytics.client.run_report(report).rows : []
        end
      end
    end
  end
end

Hyrax::Analytics::Ga4::Base.prepend(Hyrax::Analytics::Ga4::BaseDecorator)
