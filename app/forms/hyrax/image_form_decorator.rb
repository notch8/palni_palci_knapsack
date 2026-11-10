# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 Hyrax::ImageForm terms: add admin note and the PALS fields to the ActiveFedora image form.
#   No longer used; remove in a follow-up to #820.
# Wrapped in module for Zeitwerk; config runs when file is loaded.
module Hyrax
  module ImageFormDecorator
    Hyrax::ImageForm.terms = %i[admin_note] +
                             Hyrax::ImageForm.terms +
                             %i[resource_type additional_information bibliographic_citation]
    Hyrax::ImageForm.required_fields = %i[title creator keyword rights_statement resource_type]
  end
end
