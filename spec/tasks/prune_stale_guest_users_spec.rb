# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'hyku:prune_stale_guest_users' do
  let(:task_name) { 'hyku:prune_stale_guest_users' }

  before do
    Rake.application.rake_require 'tasks/prune_stale_guest_users' unless Rake::Task.task_defined?(task_name)
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    Rake::Task[task_name].reenable
  end

  def invoke(env = {})
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('BATCH_SLEEP_SECONDS', anything).and_return('0')
    env.each { |name, value| allow(ENV).to receive(:fetch).with(name, anything).and_return(value) }
    Rake::Task[task_name].invoke
  end

  let!(:stale_guest) { FactoryBot.create(:guest_user, stale: true) }
  let!(:fresh_guest) { FactoryBot.create(:guest_user) }
  let!(:stale_member) { FactoryBot.create(:user).tap { |user| user.update!(updated_at: 8.days.ago) } }

  it 'deletes only stale guest users' do
    invoke

    expect(User.unscoped.where(id: [stale_guest.id, fresh_guest.id, stale_member.id]))
      .to contain_exactly(fresh_guest, stale_member)
  end

  it 'deletes in batches' do
    FactoryBot.create(:guest_user, stale: true)

    invoke('BATCH_SIZE' => '1')

    expect(User.unscoped.where(guest: true, id: stale_guest.id)).to be_empty
    expect(User.unscoped.where(guest: true).where('updated_at < ?', 7.days.ago)).to be_empty
  end

  it 'honors OLDER_THAN_DAYS' do
    invoke('OLDER_THAN_DAYS' => '0')

    expect(User.unscoped.where(guest: true)).to be_empty
    expect(User.unscoped.find(stale_member.id)).to eq(stale_member)
  end

  it 'deletes nothing on a dry run' do
    invoke('DRY_RUN' => 'true')

    expect(User.unscoped.where(guest: true).count).to eq(2)
  end
end
