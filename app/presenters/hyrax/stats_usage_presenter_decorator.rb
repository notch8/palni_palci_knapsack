# frozen_string_literal: true

module Hyrax
  module StatsUsagePresenterDecorator
    private

    # OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- reconstruct the zero-filled chart at render time; remove once this pin includes that PR
    def zero_fill(stats)
      by_date = stats.index_by { |stat| stat.date.to_date }
      (created.to_date..Time.zone.today).map do |date|
        by_date[date]&.to_flot || [Hyrax::Statistic.convert_date(date), 0]
      end
    end
  end
end

Hyrax::StatsUsagePresenter.prepend(Hyrax::StatsUsagePresenterDecorator)
