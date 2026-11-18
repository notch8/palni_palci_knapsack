# frozen_string_literal: true

RSpec.describe Hyrax::CatalogSearchBuilder, :clean_repo do
  subject(:facet_matches) do
    builder.filter_collection_facet_for_access(solr_params)
    solr_params['f.member_of_collection_ids_ssim.facet.matches']
  end

  let(:builder) { described_class.new(context) }
  let(:context) do
    instance_double(CatalogController, blacklight_config: CatalogController.blacklight_config, current_ability: ability,
                                       search_state_class: nil)
  end
  let(:solr_params) { Blacklight::Solr::Request.new }
  let(:ability) { Ability.new(nil) }
  let!(:public_collection) { FactoryBot.valkyrie_create(:hyrax_collection, :public) }
  let!(:private_collection) { FactoryBot.valkyrie_create(:hyrax_collection) }

  it 'lets an anonymous visitor facet on public collections but not private ones' do
    expect(facet_matches).to include "^#{public_collection.id}$"
    expect(facet_matches).not_to include private_collection.id.to_s
  end
end
