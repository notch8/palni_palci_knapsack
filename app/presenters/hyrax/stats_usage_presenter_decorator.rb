# frozen_string_literal: true

module Hyrax
  module StatsUsagePresenterDecorator
    private

    # OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- reconstruct the zero-filled chart at render time; remove once this pin includes that PR
    def zero_fill(stats)
      totals = Hash.new(0)
      stats.each { |stat| totals[stat.date.to_date] += stat.send(stat.cache_column).to_i }
      (created.to_date..Time.zone.today).map { |date| [Hyrax::Statistic.convert_date(date), totals[date]] }
    end
  end
end

Hyrax::StatsUsagePresenter.prepend(Hyrax::StatsUsagePresenterDecorator)
