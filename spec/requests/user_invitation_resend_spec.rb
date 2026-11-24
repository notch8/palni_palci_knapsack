# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inviting a user who already has an account', type: :request, singletenant: true do
  include Warden::Test::Helpers

  let(:admin) { create(:admin) }
  let(:invitation_emails) { ActionMailer::Base.deliveries.select { |mail| mail.subject == 'Invitation instructions' } }

  before do
    ActionMailer::Base.deliveries.clear
    login_as(admin)
  end

  def invite(email)
    post '/users/invitation', params: { user: { email: } }
  end

  it 'resends the invitation to a user who has not accepted it' do
    invite('pending@example.edu')
    first_token = User.find_by(email: 'pending@example.edu').invitation_token

    invite('pending@example.edu')

    expect(invitation_emails.map(&:to)).to eq([['pending@example.edu'], ['pending@example.edu']])
    expect(User.find_by(email: 'pending@example.edu').invitation_token).not_to eq(first_token)
  end

  it 'does not send an invitation to a user who is already active' do
    create(:user, email: 'active@example.edu')

    invite('active@example.edu')

    expect(invitation_emails).to be_empty
  end
end
