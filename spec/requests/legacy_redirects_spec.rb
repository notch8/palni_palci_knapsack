# frozen_string_literal: true

require 'rails_helper'

# Verifies that the knapsack's legacy pittir redirects AND Hyrax's new
# database-backed redirects feature both resolve to the canonical
# /concern/<model>/<id> URL for the same work.
#
# Three entry points are exercised:
#   - GET /<legacy_id>            — knapsack legacy_redirects (pittir identifier)
#   - GET /id/eprint/<legacy_id>  — knapsack legacy_redirects (pittir admin-note)
#   - GET /<alias_path>           — Hyrax redirects catch-all (redirects property)
#
# The spec stubs the upstream Solr lookup and inserts a Hyrax::RedirectPath
# row directly so the request handlers can be verified without depending on
# the full persistence + flexible-schema + indexer chain. The contract under
# test is: given a work that has both a legacy identifier and a redirect
# alias, all three entry points 301 to the same canonical URL.
RSpec.describe 'Legacy and Hyrax redirects', type: :request, singletenant: true do
  let(:legacy_id) { '12345' }
  let(:legacy_identifier) { "https://d-scholarship.pitt.edu/#{legacy_id}" }
  let(:redirect_alias) { '/my-custom-slug' }
  let(:work_id) { 'abcd-1234' }
  let(:work_model) { 'GenericWorkResource' }
  let(:expected_path) { "/concern/#{work_model.tableize}/#{work_id}" }

  before do
    allow(Hyrax.config).to receive(:redirects_active?).and_return(true)

    # Stub the legacy controller's Solr lookup to return a doc for our work.
    fake_doc = { 'id' => work_id, 'has_model_ssim' => [work_model] }
    allow(Hyrax::SolrService).to receive(:get)
      .with(%(identifier_tesim:"#{legacy_identifier}"), rows: 1)
      .and_return('response' => { 'docs' => [fake_doc] })

    # Insert a RedirectPath row so the upstream catch-all finds a match.
    Hyrax::RedirectPath.create!(
      from_path: redirect_alias,
      to_path: expected_path,
      permalink_path: expected_path,
      resource_id: work_id,
      is_display_url: false
    )
  end

  describe 'GET /<legacy_id>' do
    it 'redirects to the canonical work URL' do
      get "/#{legacy_id}"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to end_with(expected_path)
    end
  end

  describe 'GET /id/eprint/<legacy_id>' do
    it 'redirects to the canonical work URL' do
      get "/id/eprint/#{legacy_id}"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to end_with(expected_path)
    end
  end

  describe 'GET /<redirect_alias>' do
    before do
      catch_all_present = Rails.application.routes.routes.any? do |r|
        r.path.spec.to_s.include?('*alias_path')
      end
      skip 'redirects catch-all route not present in this Hyku version' unless catch_all_present
    end

    context 'when the redirect is not a display URL' do
      it 'issues a 301 to the canonical work URL' do
        get redirect_alias
        expect(response).to have_http_status(:moved_permanently)
        expect(response.location).to end_with(expected_path)
      end
    end

    context 'when the redirect is the display URL' do
      before do
        Hyrax::RedirectPath.where(from_path: redirect_alias).update_all(
          is_display_url: true,
          to_path: redirect_alias
        )
      end

      it 'renders in place without issuing a 301' do
        get redirect_alias
        expect(response).not_to have_http_status(:moved_permanently)
        expect(response.location).to be_nil
      end
    end
  end
end
