# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 GenericWork: add the PALS properties so their values carry over when ActiveFedora works migrate to Valkyrie.
#   Client-specific, keep.
module GenericWorkDecorator
  extend ActiveSupport::Concern

  prepended do
    property :additional_information, predicate: ::RDF::Vocab::DC.accessRights do |index|
      index.as :stored_searchable
    end

    property :bibliographic_citation, predicate: ::RDF::Vocab::DC.bibliographicCitation do |index|
      index.as :stored_searchable
    end

    property :bulkrax_identifier, predicate: ::RDF::URI("https://hykucommons.org/terms/bulkrax_identifier"), multiple: false do |index|
      index.as :stored_searchable, :facetable
    end

    property :admin_note, predicate: ::RDF::Vocab::SCHEMA.positiveNotes, multiple: false do |index|
      index.as :stored_searchable
    end

    property :date, predicate: ::RDF::URI("https://hykucommons.org/terms/date"), multiple: false do |index|
      index.as :stored_searchable, :facetable
    end
    # This line must be kept below all others that set up properties,
    # including `include ::Hyrax::BasicMetadata`. All properties must
    # be declared before their values can be ordered.
    include OrderMetadataValues
  end
end

GenericWork.prepend(GenericWorkDecorator)
