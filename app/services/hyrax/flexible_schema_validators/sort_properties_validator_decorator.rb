# frozen_string_literal: true

# Override Hyrax v5.2.0 to modify confusing error message...
# date_ssi is loaded from created_date automatically via hyku_indexing module, but the message refers to
# "date" property due to the date_ssi property being used in the catalog_controller's sort field.
# To remove the misleading warning, we verify that the m3 profile actually DOES include the indexing
# property needed.
# This is also slightly misleading since the hyku_indexing module does the requisite indexing even if the profile doesn't explicitly include the property,
# but this is a more accurate warning message for the user to understand.
module Hyrax
  module FlexibleSchemaValidators
    module SortPropertiesValidatorDecorator
      # Override to validate the indexing property instead of the property name.
      def validate!
          sort_properties.each do |property|
          work_types_covered_by_indexing = profile['properties'].flat_map do |_prop_name, prop_config|
            next [] unless Array(prop_config['indexing']).include?(property)
            Array(prop_config.dig('available_on', 'class'))
          end
          properties_without_sort_properties = work_types_from_profile - work_types_covered_by_indexing
          next if properties_without_sort_properties.empty?

          msg = I18n.t(
            'hyrax.flexible_schema_validators.sort_properties_validator.warnings.message',
            property: property.sub(/_[^_]*$/, ''),
            classes: properties_without_sort_properties.join(', ')
          )
          @warnings << msg
        end
      end

      private

      # Override to find the indexing property instead of the property name.
      def find_sort_properties
        CatalogController.blacklight_config.sort_fields.keys.filter_map do |sort_key|
          index_field = sort_key.split.first
          index_field unless system_properties.include?(index_field.sub(/_[^_]*$/, ''))
        end.uniq
      end
    end
  end
end

Hyrax::FlexibleSchemaValidators::SortPropertiesValidator.prepend(Hyrax::FlexibleSchemaValidators::SortPropertiesValidatorDecorator)
