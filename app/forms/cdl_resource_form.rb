# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource CdlResource`
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see https://github.com/samvera/valkyrie/wiki/ChangeSets-and-Dirty-Tracking
class CdlResourceForm < Hyrax::Forms::ResourceForm(CdlResource)
  include Hyrax::FormFields(:basic_metadata) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:cdl_resource) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:with_video_embed) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:bulkrax_metadata) unless Hyrax.config.flexible?
  check_if_flexible(CdlResource)
  include VideoEmbedBehavior::Validation
end
