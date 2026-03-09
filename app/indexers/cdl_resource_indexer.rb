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
  check_if_flexible(CdlResource)
end
