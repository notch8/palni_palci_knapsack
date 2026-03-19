# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource CdlResource`
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see https://github.com/samvera/valkyrie/wiki/ChangeSets-and-Dirty-Tracking
class CdlResourceForm < Hyrax::Forms::ResourceForm(CdlResource)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:basic_metadata)
    include Hyrax::FormFields(:cdl_resource)
    include Hyrax::FormFields(:with_pdf_viewer)
    include Hyrax::FormFields(:with_video_embed)
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(CdlResource)

  include VideoEmbedBehavior::Validation
end
