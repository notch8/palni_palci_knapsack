# frozen_string_literal: true

RSpec.describe Hyrax::CdlsController do
  let(:cdl_resource) { FactoryBot.valkyrie_create(:cdl_resource, :with_one_file_set, depositor: 'somebody') }

  it "includes Hyrax::IiifAv::ControllerBehavior" do
    expect(described_class.include?(Hyrax::IiifAv::ControllerBehavior)).to be true
  end

  describe "#presenter" do
    subject { controller.send :presenter }

    let(:solr_document) { SolrDocument.new(FactoryBot.create(:cdl).to_solr) }

    before do
      allow(controller).to receive(:search_result_document).and_return(solr_document)
    end

    it "initializes a presenter" do
      expect(subject).to be_kind_of Hyku::WorkShowPresenter
      expect(subject.manifest_url).to eq "http://test.host/concern/cdls/#{solr_document.id}/manifest"
    end
  end
end
