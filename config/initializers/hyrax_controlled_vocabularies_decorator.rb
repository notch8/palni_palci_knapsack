# frozen_string_literal: true

# OVERRIDE Hyku 6.2.0.rc3 to add custom local authorities for flexible=false

module Hyrax
  module ControlledVocabulariesDecorator
    extend ActiveSupport::Concern
    class_methods do
      def controlled_vocab_mappings
        super.merge(
          {
            'accessibility_feature' => 'accessibility_features',
            'accessibility_hazard' => 'accessibility_hazards',
            'contributing_library' => 'contributing_libraries'
          }
        )
      end

      def services
        super.merge(
          {
            'accessibility_features' => 'Hyrax::AccessibilityFeaturesService',
            'accessibility_hazards' => 'Hyrax::AccessibilityHazardsService',
            'contributing_libraries' => 'Hyrax::ContributingLibraryService'
          }
        )
      end
    end
  end
end

Hyrax::ControlledVocabularies.prepend(Hyrax::ControlledVocabulariesDecorator)
