# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource CdlResource`
class CdlResourceIndexer < Hyrax::ValkyrieWorkIndexer
  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:basic_metadata)
    include Hyrax::Indexer(:cdl_resource)
    include Hyrax::Indexer(:bulkrax_metadata)
    include Hyrax::Indexer(:with_pdf_viewer)
    include Hyrax::Indexer(:with_video_embed)
  end

  include HykuIndexing
  check_if_flexible(CdlResource)
end
