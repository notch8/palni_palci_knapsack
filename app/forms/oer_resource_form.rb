# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource OerResource`
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see https://github.com/samvera/valkyrie/wiki/ChangeSets-and-Dirty-Tracking
class OerResourceForm < Hyrax::Forms::PcdmObjectForm(OerResource)
  include Hyrax::FormFields(:basic_metadata)
  include Hyrax::FormFields(:oer_resource)
  include Hyrax::FormFields(:with_pdf_viewer)
  include Hyrax::FormFields(:with_video_embed)

  # Define custom form fields using the Valkyrie::ChangeSet interface
  #
  # property :my_custom_form_field

  # if you want a field in the form, but it doesn't have a directly corresponding
  # model attribute, make it virtual
  #
  # property :user_input_not_destined_for_the_model, virtual: true
end
