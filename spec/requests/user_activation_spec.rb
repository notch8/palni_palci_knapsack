# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Activating an invited user', type: :request, singletenant: true do
  include Warden::Test::Helpers

  let(:admin) { create(:admin) }
  let!(:invitee) { User.invite!({ email: 'invitee@example.edu' }, admin) }
  let(:mail) { ActionMailer::Base.deliveries.last }

  before do
    ActionMailer::Base.deliveries.clear
    login_as(admin)
    post "/admin/users/#{invitee.id}/activate"
  end

  it 'emails the user a link to set their own password' do
    expect(mail.to).to eq([invitee.email])
    expect(mail.subject).to eq('Your account has been activated')
    expect(mail.body.encoded).to include('/users/password/edit?reset_password_token=')
  end

  it 'sends a link that sets a password the user can sign in with' do
    token = mail.body.encoded[/reset_password_token=([^"&]+)/, 1]
    logout
    put '/users/password', params: { user: { reset_password_token: token, password: 'Chosen-Passw0rd!', password_confirmation: 'Chosen-Passw0rd!' } }

    expect(invitee.reload.valid_password?('Chosen-Passw0rd!')).to be(true)
  end

  it 'says the link expires and does not tell the user to ignore it' do
    expect(mail.body.encoded).to include('This link expires in 6 hours')
    expect(mail.body.encoded).not_to include('ignore this email')
  end

  it 'sends one email when Activate is submitted twice' do
    post "/admin/users/#{invitee.id}/activate"

    expect(ActionMailer::Base.deliveries.count { |m| m.subject == 'Your account has been activated' }).to eq(1)
  end

  context 'when the user has already accepted their invitation' do
    let(:active_user) { create(:user, password: 'Existing-Passw0rd!', password_confirmation: 'Existing-Passw0rd!') }

    it 'leaves their password alone and sends no email' do
      ActionMailer::Base.deliveries.clear
      post "/admin/users/#{active_user.id}/activate"

      expect(active_user.reload.valid_password?('Existing-Passw0rd!')).to be(true)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context 'when the user does not belong to this repository' do
    let(:outsider) { User.invite!({ email: 'elsewhere@example.edu' }, admin).tap { |user| user.roles.destroy_all } }

    it 'does not activate them' do
      post "/admin/users/#{outsider.id}/activate"

      expect(response).to have_http_status(:not_found)
      expect(outsider.reload.invitation_accepted?).to be(false)
    end
  end
end
