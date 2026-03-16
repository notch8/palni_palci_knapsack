# frozen_string_literal: true

# OVERRIDE Hyku 6.2.0.rc3 to add custom local authorities for flexible=false

module Hyrax
  module ControlledVocabulariesDecorator
    extend ActiveSupport::Concern
    class_methods do
      def controlled_vocab_mappings
        super.merge(
          {
            'contributing_library' => 'contributing_libraries'
          }
        )
      end

      def services
        super.merge(
          {
            'contributing_libraries' => 'Hyrax::ContributingLibraryService'
          }
        )
      end
    end
  end
end

Hyrax::ControlledVocabularies.prepend(Hyrax::ControlledVocabulariesDecorator)
