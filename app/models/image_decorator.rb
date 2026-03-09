# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work Image`
# Empty module for Zeitwerk (this file defines Image, not a decorator mixin).
module ImageDecorator
end

class Image < ActiveFedora::Base
  include ::Hyrax::WorkBehavior
  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWork,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )
  include PdfBehavior
  include VideoEmbedBehavior

  self.indexer = ImageIndexer

  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  property :extent, predicate: ::RDF::Vocab::DC.extent, multiple: true do |index|
    index.as :stored_searchable
  end

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

  # This must come after the properties because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
  # This line must be kept below all others that set up properties,
  # including `include ::Hyrax::BasicMetadata`. All properties must
  # be declared before their values can be ordered.
  include OrderMetadataValues

  # These needed to be added again in order to enable destroy for based_near, even though they are in Hyrax::BasicMetadata.
  # the OrderAlready OrderMetadataValues above somehow prevents them from running
  id_blank = proc { |attributes| attributes[:id].blank? }
  class_attribute :controlled_properties
  self.controlled_properties = [:based_near]
  accepts_nested_attributes_for :based_near, reject_if: id_blank, allow_destroy: true

  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }
end
