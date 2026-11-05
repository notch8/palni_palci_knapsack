# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::BulkraxGeneratedFlagRemover do
  subject(:remover) { described_class.new(account, dry_run:) }

  let(:dry_run) { false }
  let(:account) { create(:account) }
  let(:custom_mappings) do
    {
      'Bulkrax::CsvParser' => {
        'abstract' => { 'from' => ['abstract', 'summary'], 'split' => '\|', 'generated' => true },
        'rights_statement' => { 'from' => ['rights'], 'generated' => true },
        'depositor' => { 'from' => ['depositor'], 'generated' => true },
        'title' => { 'from' => ['title'], 'split' => '\|' }
      },
      'Bulkrax::BagitParser' => {
        'source' => { 'from' => ['source'], 'generated' => 'false' }
      }
    }
  end

  def stored_mappings
    JSON.parse(account.reload.settings['bulkrax_field_mappings'])
  end

  context 'with a saved custom mapping' do
    before do
      account.bulkrax_field_mappings = JSON.pretty_generate(custom_mappings)
      account.save!
    end

    it 'removes the flag from the listed fields in every parser and leaves the rest alone' do
      expect(remover.call).to contain_exactly(
        'Bulkrax::CsvParser.abstract', 'Bulkrax::CsvParser.rights_statement', 'Bulkrax::BagitParser.source'
      )

      csv = stored_mappings['Bulkrax::CsvParser']
      expect(csv['abstract']).to eq('from' => ['abstract', 'summary'], 'split' => '\|')
      expect(csv['rights_statement']).to eq('from' => ['rights'])
      expect(csv['depositor']).to include('generated' => true)
      expect(csv['title']).to eq('from' => ['title'], 'split' => '\|')
      expect(stored_mappings['Bulkrax::BagitParser']['source']).to eq('from' => ['source'])
    end

    it 'does not add listed fields the tenant has removed' do
      remover.call
      expect(stored_mappings['Bulkrax::CsvParser']).not_to have_key('alternative_title')
    end

    it 'reports nothing on a second run' do
      remover.call
      expect(described_class.new(account.reload).call).to be_empty
    end

    context 'when dry_run' do
      let(:dry_run) { true }

      it 'reports the changes without saving them' do
        expect(remover.call).to include('Bulkrax::CsvParser.abstract')
        expect(stored_mappings).to eq(custom_mappings)
      end
    end
  end

  context 'without a saved mapping' do
    it 'changes nothing' do
      expect(remover.call).to be_empty
      expect(account.reload.settings['bulkrax_field_mappings']).to be_nil
    end
  end
end
