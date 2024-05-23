# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength

Rails.application.config.after_initialize do
  # Add all concerns that are migrating from ActiveFedora here
  CONCERNS = [Cdl, Etd, GenericWork, Image, Oer].freeze

  CONCERNS.each do |klass|
    Wings::ModelRegistry.register("#{klass}Resource".constantize, klass)
    # we register itself so we can pre-translate the class in Freyja instead of having to translate in each query_service
    Wings::ModelRegistry.register(klass, klass)
  end

  Wings::ModelRegistry.register(CdlResource, Cdl)
  Wings::ModelRegistry.register(EtdResource, Etd)
  Wings::ModelRegistry.register(GenericWorkResource, GenericWork)
  Wings::ModelRegistry.register(ImageResource, Image)
  Wings::ModelRegistry.register(OerResource, Oer)

  Valkyrie.config.resource_class_resolver = lambda do |resource_klass_name|
    # TODO: Can we use some kind of lookup.
    klass_name = resource_klass_name.gsub(/Resource$/, '')
    if CONCERNS.map(&:to_s).include?(klass_name)
      "#{klass_name}Resource".constantize
    elsif 'Collection' == klass_name
      CollectionResource
    elsif 'AdminSet' == klass_name
      AdminSetResource
    # Without this mapping, we'll see cases of Postgres Valkyrie adapter attempting to write to
    # Fedora.  Yeah!
    elsif 'Hydra::AccessControl' == klass_name
      Hyrax::AccessControl
    elsif 'FileSet' == klass_name
      Hyrax::FileSet
    elsif 'Hydra::AccessControls::Embargo' == klass_name
      Hyrax::Embargo
    elsif 'Hydra::AccessControls::Lease' == klass_name
      Hyrax::Lease
    elsif 'Hydra::PCDM::File' == klass_name
      Hyrax::FileMetadata
    else
      klass_name.constantize
    end
  end
end
# rubocop:enable Metrics/BlockLength
