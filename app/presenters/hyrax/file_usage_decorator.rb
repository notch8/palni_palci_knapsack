# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7676
# Temporary hotfix; delete this file once the Hyku pin includes the merged upstream fix.
# OVERRIDE Hyrax 1489c95: adds #without_analytics, used by Hyrax::StatsControllerDecorator.
module Hyrax
  module FileUsageDecorator
    # Zero-filled charts for when the analytics provider can't be reached.
    def without_analytics
      @downloads = zero_fill([])
      @pageviews = zero_fill([])
      self
    end
  end
end

Hyrax::FileUsage.prepend(Hyrax::FileUsageDecorator)
