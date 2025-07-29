# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource CdlResource`
class CdlResourceIndexer < Hyrax::ValkyrieWorkIndexer
  include Hyrax::Indexer(:basic_metadata) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:cdl_resource) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:bulkrax_metadata) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:with_video_embed) unless Hyrax.config.flexible?

  include HykuIndexing
  include Hyrax::Indexer('CdlResource') if Hyrax.config.flexible?

  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
