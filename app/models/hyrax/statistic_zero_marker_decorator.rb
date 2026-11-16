# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7674 (find every piece with `git grep -l HYRAX-BACKPORT`)
# Delete once the Hyku pin includes samvera/hyrax#7674: edtf's Date#<=> makes the Date vs TimeWithZone compare raise.
module Hyrax
  module StatisticZeroMarkerDecorator
    private

    # OVERRIDE Hyrax 5.3.0: compare `date` with `marker.date.to_date`
    def advance_zero_marker(object, object_method, date, user_id)
      marker = statistics_for(object).where(object_method => 0).order(date: :asc).last
      if marker
        marker.update(date:) if date > marker.date.to_date
      else
        build_for(object, date:, object_method => 0, user_id:).save
      end
    end
  end
end

Hyrax::Statistic.singleton_class.prepend(Hyrax::StatisticZeroMarkerDecorator)
