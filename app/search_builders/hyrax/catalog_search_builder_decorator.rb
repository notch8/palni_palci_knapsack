# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7756 (find every piece with `git grep -l HYRAX-BACKPORT`)
# Delete once the Hyku pin includes it: anonymous OAI ListSets and catalog facets dropped every public collection.
module Hyrax
  module CatalogSearchBuilderDecorator
    # OVERRIDE Hyrax 5.3.0 Hyrax::CatalogSearchBuilder#filter_collection_facet_for_access: allow the collections
    # the user can see in Solr, not only those they participate in, unless hidden from catalog search.
    def filter_collection_facet_for_access(solr_parameters)
      return if current_ability.admin?

      collection_ids = collection_ids_for_facet.map { |id| "^#{id}$" }
      solr_parameters['f.member_of_collection_ids_ssim.facet.matches'] = collection_ids.present? ? collection_ids.join('|') : '^$'
    end

    private

    def collection_ids_for_facet
      query = Hyrax::SolrQueryService.new(query: ['-hide_from_catalog_search_bsi:true'])
                                     .with_field_pairs(field_pairs: { has_model_ssim: Hyrax::ModelRegistry.collection_rdf_representations.join(',') },
                                                       type: 'terms')
                                     .accessible_by(ability: current_ability)
                                     .build
      id_field = Hyrax.config.id_field
      ids = []
      Hyrax::SolrService.query_in_batches(query, fl: id_field, sort: "#{id_field} asc") { |hit| ids << hit.id }
      ids
    end
  end
end

Hyrax::CatalogSearchBuilder.prepend(Hyrax::CatalogSearchBuilderDecorator)
