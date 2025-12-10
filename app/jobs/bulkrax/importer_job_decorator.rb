# frozen_string_literal: true

# OVERRIDE BULKRAX 8.0.0
module Bulkrax
  module ImporterJobDecorator
    def import(importer, only_updates_since_last_import)
      super

      return if importer.failed?

      importer&.create_memberships unless importer.validate_only
    end
  end
end

Bulkrax::ImporterJob.prepend(Bulkrax::ImporterJobDecorator)
