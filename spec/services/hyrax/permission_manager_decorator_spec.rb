# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hyrax::PermissionManager do
  subject(:manager) { described_class.new(resource:) }
  let(:resource) { Hyrax::Resource.new }
  let(:user) { create(:user).user_key.to_s }
  let(:missing_user) { 'deleted@example.com' }

  it 'skips edit users with no matching User' do
    manager.edit_users = [user, missing_user]

    expect(manager.edit_users).to contain_exactly(user)
  end

  it 'skips read users with no matching User' do
    manager.read_users = [missing_user, user]

    expect(manager.read_users).to contain_exactly(user)
  end

  it 'logs the skipped users' do
    expect(Hyrax.logger).to receive(:warn).with(/#{missing_user}/)

    manager.edit_users = [missing_user]
  end
end
