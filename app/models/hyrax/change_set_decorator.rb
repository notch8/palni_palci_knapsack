# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to add validation of controlled vocabularies
#   can be removed when it is in core Hyrax https://github.com/samvera/hyrax/pull/7423

module Hyrax
  module ChangeSetDecorator
    extend ActiveSupport::Concern

    prepended do
      validates_with Hyrax::ControlledVocabularyValidator
    end
  end
end

Hyrax::ChangeSet.prepend(Hyrax::ChangeSetDecorator)
