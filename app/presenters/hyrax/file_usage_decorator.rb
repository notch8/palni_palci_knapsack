# frozen_string_literal: true

module Hyrax
  module FileUsageDecorator
    private

    # OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- use zero_fill instead of a bare to_flots; remove once this pin includes that PR
    def downloads
      @downloads ||= zero_fill(FileDownloadStat.statistics(model, created, user_id))
    end

    def pageviews
      @pageviews ||= zero_fill(FileViewStat.statistics(model, created, user_id))
    end
  end
end

Hyrax::FileUsage.prepend(Hyrax::FileUsageDecorator)
