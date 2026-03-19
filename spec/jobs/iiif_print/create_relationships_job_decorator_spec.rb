# frozen_string_literal: true

# rubocop:disable RSpec/FilePath
RSpec.describe IiifPrint::CreateRelationshipsJobDecorator, type: :decorator do
  describe '#perform' do
    subject(:job) { IiifPrint::Jobs::CreateRelationshipsJob.new }

    let(:parent) { FactoryBot.create(:cdl) }
    let(:child) { FactoryBot.create(:generic_work) }

    after do
      job.perform(parent_id: parent.id, parent_model: parent.class.to_s, child_model: child.class)
    end

    context 'when parent_model is Cdl' do
      it 'calls CreateGroupAndAddMembersJob' do
        expect(CreateGroupAndAddMembersJob).to receive(:set).with(wait: 2.minutes).and_return(CreateGroupAndAddMembersJob)
      end
    end

    context 'when parent_model is not Cdl' do
      let(:parent) { FactoryBot.create(:generic_work) }

      it 'does not call CreateGroupAndAddMembersJob' do
        expect(CreateGroupAndAddMembersJob).not_to receive(:set)
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
