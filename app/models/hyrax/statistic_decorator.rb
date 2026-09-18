# frozen_string_literal: true

# OVERRIDE Hyrax hyrax-v3.5.0 to require Hyrax::Pageview so the method below doesn't fail

Hyrax::Pageview # rubocop:disable Lint/Void

module Hyrax
  module StatisticClassDecorator
    # Hyrax::Pageview is sent to Hyrax::Analytics.profile as #hyrax__pageview
    # see Legato::ProfileMethods.method_name_from_klass
    def ga_statistics(start_date, object)
      path = polymorphic_path(object)
      profile = Hyrax::Analytics.profile
      unless profile
        Rails.logger.error("Google Analytics profile has not been established. Unable to fetch statistics.")
        return []
      end
      # OVERRIDE Hyrax hyrax-v3.5.0
      profile.hyrax__pageview(sort: 'date',
                              start_date:,
                              end_date: Date.yesterday,
                              limit: 10_000)
             .for_path(path)
    end

    # OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- collapse zero-count days into one marker row; remove once this pin includes that PR
    def combined_stats(object, start_date, object_method, ga_key, user_id = nil)
      stat_cache_info = cached_stats(object, start_date, object_method)
      stats = stat_cache_info[:cached_stats]
      if stat_cache_info[:ga_start_date] < Time.zone.today
        page_stats = Hyrax::Analytics.page_statistics(stat_cache_info[:ga_start_date], object)
        latest_zero_date = nil
        page_stats.each do |stat|
          lstat, zero_date = record_stat(object, stat, object_method, ga_key, user_id)
          stats << lstat
          latest_zero_date = [latest_zero_date, zero_date].compact.max
        end
        advance_zero_marker(object, object_method, latest_zero_date, user_id) if latest_zero_date
      end
      stats
    end

    # @return [Array(Hyrax::Statistic, Date?)] the built stat, and its date if zero-count
    def record_stat(object, stat, object_method, ga_key, user_id)
      lstat = build_for(object, date: stat[:date], object_method => stat[ga_key], user_id:)
      return [lstat, nil] if stat[:date].to_date == Time.zone.today
      return [lstat, stat[:date].to_date] unless stat[ga_key].to_i.positive?

      lstat.save
      [lstat, nil]
    end

    def advance_zero_marker(object, object_method, date, user_id)
      marker = statistics_for(object).where(object_method => 0).order(date: :asc).last
      if marker
        marker.update(date:) if date > marker.date
      else
        build_for(object, date:, object_method => 0, user_id:).save
      end
    end
  end
end

Hyrax::Statistic.singleton_class.send(:prepend, Hyrax::StatisticClassDecorator)
