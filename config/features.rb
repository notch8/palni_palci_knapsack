# frozen_string_literal: true

Flipflop.configure do
  feature :validate_local_controlled_vocabulary,
          default: false,
          description: "Validate local controlled vocabulary."
end
