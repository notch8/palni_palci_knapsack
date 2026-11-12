# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 so the current page's search params (facets, q, page) stop filtering
# the collection list, which emptied "Add to Collection" after any "Filter works" choice.
# Remove once the Hyrax fix reaches this knapsack through a Hyku bump.
module Hyrax
  module CollectionsServiceDecorator
    def initialize(context)
      super
      @search_state = Blacklight::SearchState.new({}, blacklight_config)
      @user_params = @search_state.params
    end
  end
end

Hyrax::CollectionsService.prepend(Hyrax::CollectionsServiceDecorator)
