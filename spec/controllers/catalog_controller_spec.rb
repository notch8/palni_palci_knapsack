# frozen_string_literal: true

require "rails_helper"

RSpec.describe CatalogController do
  # Hyku Solr configsets typically omit per-field spellcheck dictionaries; sending
  # spellcheck.dictionary=creator (etc.) causes Solr errors and Blacklight InvalidRequest.
  describe "search field Solr params (spellcheck regression)" do
    %w[creator keyword title contributor subject].each do |key|
      it "does not set spellcheck.dictionary on #{key} search field" do
        field = described_class.blacklight_config.search_fields[key]
        expect(field).to be_present, "expected search_fields['#{key}'] to exist"
        solr_keys = (field.solr_parameters || {}).stringify_keys.keys
        expect(solr_keys).not_to include("spellcheck.dictionary")
      end
    end
  end

  describe "date facet" do
    let(:facet_fields) { described_class.blacklight_config.facet_fields }

    it "ranges over the integer years Hyku indexes, not the date_ssi string" do
      expect(facet_fields).to have_key(DateRangeIndexing::SOLR_FIELD)
      expect(facet_fields[DateRangeIndexing::SOLR_FIELD].label).to eq('Date Created')
      expect(facet_fields).not_to have_key('date_ssi')
    end
  end
end
