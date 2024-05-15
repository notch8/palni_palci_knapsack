# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource EtdResource`
class EtdResource < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:etd_resource)
  include Hyrax::Schema(:with_pdf_viewer)
  include Hyrax::Schema(:with_video_embed)
  include Hyrax::ArResource
  include Hyrax::NestedWorks

  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWorkResource,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )

  prepend OrderAlready.for(:creator)
end
