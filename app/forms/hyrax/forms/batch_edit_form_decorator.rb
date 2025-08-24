# frozen_string_literal: true

## Override from Hyrax 5.0 to remove description and resource_type
## those fields are different in OER and cannot be bulk edited
## Also needs to correspond with the terms in batch_edit_metadata.yaml
module Hyrax
  module Forms
    module BatchEditFormDecorator
      def self.decorate(base)
        # Set the terms
        base.class_eval do
          self.terms = %i[creator contributor
                          keyword license publisher date_created
                          subject language identifier based_near
                          related_url]
        end
      end
    end
  end
end

Hyrax::Forms::BatchEditFormDecorator.decorate(Hyrax::Forms::BatchEditForm)
