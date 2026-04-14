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
end
