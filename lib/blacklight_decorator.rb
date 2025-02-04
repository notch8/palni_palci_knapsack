# frozen_string_literal: true

# OVERRIDE Blacklight v7.35.0 to hardcode the repository_class to `Blacklight::Solr::Repository`
#   sometimes in the worker, we're seeing it lose the information from the blacklight.yml
module BlacklightDecorator
  extend ActiveSupport::Concern

  class_methods do
    def repository_class
      Blacklight::Solr::Repository
    end
  end
end

Blacklight.prepend(BlacklightDecorator)
