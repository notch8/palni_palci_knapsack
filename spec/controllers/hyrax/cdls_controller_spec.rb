# frozen_string_literal: true

RSpec.describe Hyrax::CdlsController, type: :controller do
  let(:cdl_resource) { FactoryBot.valkyrie_create(:cdl_resource, :with_one_file_set, depositor: 'somebody') }

  it "includes Hyrax::IiifAv::ControllerBehavior" do
    expect(described_class.include?(Hyrax::IiifAv::ControllerBehavior)).to be true
  end

  describe "#presenter" do
    subject { controller.send :presenter }

    let(:solr_hash) do
      {
        'has_model_ssim' => ['Cdl'],
        'id' => 'abc123',
        'title_tesim' => ['Test title']
      }
    end

    let(:solr_document) do
      SolrDocument.new(solr_hash)
    end

    before do
      allow_any_instance_of(described_class).to receive(:search_result_document).and_return(solr_document)
      get :show, params: { id: solr_document.id }
    end

    it "initializes a presenter" do
      expect(subject).to be_kind_of Hyku::WorkShowPresenter
      expect(subject.manifest_url).to eq "http://test.host/concern/cdls/#{solr_document.id}/manifest"
    end
  end
end
