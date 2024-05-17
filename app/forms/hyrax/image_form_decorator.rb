# frozen_string_literal: true

Hyrax::ImageForm.terms = %i[admin_note] +
                               Hyrax::ImageForm.terms +
                               %i[resource_type additional_information bibliographic_citation]
Hyrax::ImageForm.required_fields = %i[title creator keyword rights_statement resource_type]
