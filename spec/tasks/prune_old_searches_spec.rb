# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'hyku:prune_old_searches' do
  let(:task_name) { 'hyku:prune_old_searches' }
  let(:account) { instance_double(Account, tenant: 'public', cname: 'example.test') }

  before do
    Rake.application.rake_require 'tasks/prune_old_searches' unless Rake::Task.task_defined?(task_name)
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    allow(Account).to receive(:find_each).and_yield(account)
    Rake::Task[task_name].reenable
  end

  def invoke(env = {})
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('BATCH_SLEEP_SECONDS', anything).and_return('0')
    env.each { |name, value| allow(ENV).to receive(:fetch).with(name, anything).and_return(value) }
    Rake::Task[task_name].invoke
  end

  let!(:old_anonymous) { Search.create!(query_params: { q: 'old' }, created_at: 40.days.ago) }
  let!(:recent_anonymous) { Search.create!(query_params: { q: 'recent' }, created_at: 1.day.ago) }
  let!(:old_saved) { Search.create!(query_params: { q: 'saved' }, user_id: 1, created_at: 40.days.ago) }

  it 'deletes only old searches that no user saved' do
    invoke

    expect(Search.all).to contain_exactly(recent_anonymous, old_saved)
  end

  it 'deletes in batches' do
    Search.create!(query_params: { q: 'old2' }, created_at: 41.days.ago)

    invoke('BATCH_SIZE' => '1')

    expect(Search.all).to contain_exactly(recent_anonymous, old_saved)
  end

  it 'honors OLDER_THAN_DAYS' do
    invoke('OLDER_THAN_DAYS' => '0')

    expect(Search.all).to contain_exactly(old_saved)
  end

  it 'deletes nothing on a dry run' do
    invoke('DRY_RUN' => 'true')

    expect(Search.count).to eq(3)
  end

  it 'prunes each tenant inside its own Apartment schema' do
    allow(Apartment::Tenant).to receive(:switch).and_call_original

    invoke

    expect(Apartment::Tenant).to have_received(:switch).with('public')
  end

  it 'keeps going after a tenant fails, then exits non-zero naming it' do
    other = instance_double(Account, tenant: 'public', cname: 'other.test')
    allow(Account).to receive(:find_each).and_yield(account).and_yield(other)
    calls = 0
    allow(Search).to receive(:where).and_wrap_original do |original, *args|
      calls += 1
      raise ActiveRecord::StatementInvalid, 'boom' if calls == 1

      original.call(*args)
    end

    expect { invoke }.to raise_error(SystemExit).and output(/failed for: example.test/).to_stderr
    expect(Search.all).to contain_exactly(recent_anonymous, old_saved)
  end
end
