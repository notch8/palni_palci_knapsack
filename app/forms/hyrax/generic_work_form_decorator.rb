# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 Hyrax::GenericWorkForm terms: add admin note and the PALS fields to the ActiveFedora work form.
#   No longer used; remove in a follow-up to #820.
# Wrapped in module for Zeitwerk; config runs when file is loaded.
module Hyrax
  module GenericWorkFormDecorator
    Hyrax::GenericWorkForm.terms = %i[admin_note] +
                                   Hyrax::GenericWorkForm.terms +
                                   %i[resource_type additional_information bibliographic_citation]
    Hyrax::GenericWorkForm.required_fields = %i[title creator keyword rights_statement resource_type]
  end
end
