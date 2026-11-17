# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SWORD link host', type: :request, singletenant: true do
  let(:tenant_host) { 'tenant.example.org' }
  let(:sword_host) { 'sword.example.org' }
  let(:atom) { { 'atom' => 'http://www.w3.org/2005/Atom' } }
  let(:doc) { Nokogiri::XML(response.body) }

  before { create(:admin, email: 'admin@example.com', api_key: 'test') }

  around do |example|
    original = WillowSword.setup.sword_allowed_hosts
    WillowSword.setup.sword_allowed_hosts = [sword_host]
    example.run
  ensure
    WillowSword.setup.sword_allowed_hosts = original
  end

  def sword_get(path, extra_headers = {})
    get path, headers: { 'Api-key' => 'test', 'Host' => tenant_host }.merge(extra_headers)
  end

  describe 'GET /sword/v2/service_document' do
    before do
      allow_any_instance_of(WillowSword::V2::ServiceDocumentsController).to receive(:admin_set_ids).and_return(['as-1'])
      allow_any_instance_of(WillowSword::V2::ServiceDocumentsController).to receive(:collection_ids).and_return([])
      allow(Hyrax::SolrService).to receive(:query)
        .and_return([{ 'id' => 'as-1', 'title_tesim' => ['Deposits'], 'has_model_ssim' => ['AdminSet'] }])
    end

    let(:collection_href) { doc.at_xpath('//*[local-name()="collection"]')['href'] }

    it 'builds collection hrefs on the SWORD host' do
      sword_get '/sword/v2/service_document', 'X-Sword-Host' => sword_host

      expect(collection_href).to eq("http://#{sword_host}/sword/v2/collections/as-1")
    end

    it 'keeps the tenant host when the request did not come through a SWORD host' do
      sword_get '/sword/v2/service_document'

      expect(collection_href).to eq("http://#{tenant_host}/sword/v2/collections/as-1")
    end

    it 'ignores an X-Sword-Host that is not in SWORD_ALLOWED_HOSTS' do
      sword_get '/sword/v2/service_document', 'X-Sword-Host' => 'attacker.example.org'

      expect(collection_href).to eq("http://#{tenant_host}/sword/v2/collections/as-1")
    end

    it 'ignores an X-Sword-Host that is not a bare hostname' do
      sword_get '/sword/v2/service_document', 'X-Sword-Host' => 'evil.example.org/phish?'

      expect(collection_href).to eq("http://#{tenant_host}/sword/v2/collections/as-1")
    end
  end

  describe 'GET /sword/v2/works/:id' do
    let(:file_set) { valkyrie_create(:hyrax_file_set, title: ['File']) }
    let!(:work) do
      valkyrie_create(:generic_work_resource, title: ['Deposited Work'], creator: ['A Creator'], member_ids: [file_set.id])
        .tap { |resource| Hyrax.index_adapter.save(resource:) }
    end

    let(:links) { doc.root.xpath('atom:link', atom).to_h { |link| [link['rel'], link['href']] } }
    let(:content_src) { doc.root.at_xpath('atom:content', atom)['src'] }

    it 'puts edit and edit-media links on the SWORD host and the content link on the tenant host' do
      sword_get "/sword/v2/works/#{work.id}", 'X-Sword-Host' => sword_host

      expect(response).to have_http_status(:ok)
      expect(links['edit']).to eq("http://#{sword_host}/sword/v2/works/#{work.id}")
      expect(links['edit-media']).to eq("http://#{sword_host}/sword/v2/file_sets/#{file_set.id}")
      expect(content_src).to start_with("http://#{tenant_host}/concern/")
    end

    it 'keeps every link on the tenant host without X-Sword-Host' do
      sword_get "/sword/v2/works/#{work.id}"

      expect(links['edit']).to eq("http://#{tenant_host}/sword/v2/works/#{work.id}")
      expect(links['edit-media']).to eq("http://#{tenant_host}/sword/v2/file_sets/#{file_set.id}")
      expect(content_src).to start_with("http://#{tenant_host}/concern/")
    end
  end
end
