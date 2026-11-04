# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'bulkrax:ungenerate_descriptive_fields' do
  let(:task_name) { 'bulkrax:ungenerate_descriptive_fields' }
  let!(:tenant) { create(:account, name: 'tenant') }
  let!(:search) { create(:account, name: 'search') }

  before do
    Rake.application.rake_require 'tasks/bulkrax' unless Rake::Task.task_defined?(task_name)
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    tenant.bulkrax_field_mappings = { 'Bulkrax::CsvParser' => { 'abstract' => { 'from' => ['abstract'], 'generated' => true } } }.to_json
    tenant.save!
  end

  def run_task
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke
  end

  it 'updates each tenant except search and reports what changed' do
    expect { run_task }.to output(/tenant: updated Bulkrax::CsvParser\.abstract/).to_stdout
    expect(JSON.parse(tenant.reload.settings['bulkrax_field_mappings'])['Bulkrax::CsvParser']['abstract']).not_to have_key('generated')
  end

  it 'skips the search account' do
    expect { run_task }.not_to output(/search:/).to_stdout
  end

  it 'only previews with DRY_RUN=true' do
    stub_const('ENV', ENV.to_h.merge('DRY_RUN' => 'true'))
    expect { run_task }.to output(/tenant: would update Bulkrax::CsvParser\.abstract/).to_stdout
    expect(JSON.parse(tenant.reload.settings['bulkrax_field_mappings'])['Bulkrax::CsvParser']['abstract']).to include('generated' => true)
  end
end
