# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource CdlResource`
class CdlResource < Hyrax::Work
  include Hyrax::Schema(:basic_metadata) unless Hyrax.config.flexible?
  include Hyrax::Schema(:cdl_resource) unless Hyrax.config.flexible?
  include Hyrax::Schema(:bulkrax_metadata) unless Hyrax.config.flexible?
  include Hyrax::Schema(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::Schema(:with_video_embed) unless Hyrax.config.flexible?
  include Hyrax::ArResource
  include Hyrax::NestedWorks
  # include specifically so specs will include it, as flexible? was false in hyrax's code
  # in the Resource module, resulting in unexpected behavior for the specs.
  include Hyrax::Flexibility

  Hyrax::ValkyrieLazyMigration.migrating(self, from: Cdl)

  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWorkResource,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )

  prepend OrderAlready.for(:creator) unless Hyrax.config.flexible?
end
