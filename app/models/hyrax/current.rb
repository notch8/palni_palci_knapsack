# frozen_string_literal: true
# Matches samvera/hyrax#7642 -- delete once that's merged and the gem pin picks it up.
class Hyrax::Current < ActiveSupport::CurrentAttributes
  attribute :flexible_schema
end
