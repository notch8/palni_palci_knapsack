# frozen_string_literal: true

module HykuKnapsack
  module OAI
    module Provider
      module ModelDecorator
        # OVERRIDE Hyku v7.1.0 Oai::Provider::ModelDecorator#map_oai_hyku: leave owner, depositor and system dates out of OAI.
        #   Client-specific, keep.
        def map_oai_hyku
          super.reject { |key, _| %i[owner date_modified date_uploaded depositor].include?(key) }
        end
      end
    end
  end
end

OAI::Provider::Model.prepend(HykuKnapsack::OAI::Provider::ModelDecorator)
