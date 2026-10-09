# frozen_string_literal: true

# OVERRIDE blacklight_range_limit v8.5.0 to pin the "view distribution" link to the catalog.
#   Upstream resolves `action: 'range_limit'` against the current controller, so on the
#   homepage (heritage / cultural_repository themes render facets there) it looks for
#   hyrax/homepage#range_limit, which has no route, and the page 500s.
#   Same fix Hyku applies to `search_facet_path` in Hyrax::HomepageController.

module BlacklightRangeLimit
  module RangeFacetComponentDecorator
    def range_limit_url(options = {})
      super(options.merge(controller: '/catalog'))
    end
  end
end

BlacklightRangeLimit::RangeFacetComponent.prepend(BlacklightRangeLimit::RangeFacetComponentDecorator)
