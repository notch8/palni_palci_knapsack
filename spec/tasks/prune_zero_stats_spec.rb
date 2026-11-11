# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'hyku:prune_zero_stats' do
  let(:task_name) { 'hyku:prune_zero_stats' }
  let(:account) { instance_double(Account, tenant: 'public', cname: 'example.test') }

  before do
    Rake.application.rake_require 'tasks/prune_zero_stats' unless Rake::Task.task_defined?(task_name)
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    allow(Account).to receive(:find_each).and_yield(account)
    Rake::Task[task_name].reenable
  end

  def invoke(env = {})
    allow(ENV).to receive(:fetch).and_call_original
    env.each { |name, value| allow(ENV).to receive(:fetch).with(name, anything).and_return(value) }
    Rake::Task[task_name].invoke
  end

  it 'keeps the newest zero row and all non-zero rows per object' do
    kept_zero = FileViewStat.create!(file_id: 'abc', views: 0, date: 2.days.ago)
    FileViewStat.create!(file_id: 'abc', views: 0, date: 10.days.ago)
    real_view = FileViewStat.create!(file_id: 'abc', views: 3, date: 5.days.ago)
    kept_work = WorkViewStat.create!(work_id: 'w1', work_views: 0, date: 1.day.ago)
    WorkViewStat.create!(work_id: 'w1', work_views: 0, date: 4.days.ago)

    invoke

    expect(FileViewStat.all).to contain_exactly(kept_zero, real_view)
    expect(WorkViewStat.all).to contain_exactly(kept_work)
  end

  it 'deletes nothing on a dry run' do
    FileDownloadStat.create!(file_id: 'abc', downloads: 0, date: 2.days.ago)
    FileDownloadStat.create!(file_id: 'abc', downloads: 0, date: 10.days.ago)

    invoke('DRY_RUN' => 'true')

    expect(FileDownloadStat.count).to eq(2)
  end

  it 'prunes each tenant inside its own Apartment schema' do
    allow(Apartment::Tenant).to receive(:switch).and_call_original

    invoke

    expect(Apartment::Tenant).to have_received(:switch).with('public')
  end

  it 'lets a tenant failure abort the run' do
    allow(Hyrax::StatsPruner).to receive(:call).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { invoke }.to raise_error(ActiveRecord::StatementInvalid, /boom/)
  end
end
