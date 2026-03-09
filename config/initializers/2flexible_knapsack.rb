# frozen_string_literal: true

# Override HYRAX_FLEXIBLE_CLASSES with knapsack-specific work types.
# This replaces the submodule's 1flexible.rb classes with our custom classes
# matching the m3_profile.yaml.

flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'false'))
if flexible
  knapsack_classes = %w[
    AdminSetResource
    CollectionResource
    Hyrax::FileSet
    GenericWorkResource
    ImageResource
    EtdResource
    OerResource
    CdlResource
  ]

  ENV['HYRAX_FLEXIBLE_CLASSES'] = knapsack_classes.join(',')
end
