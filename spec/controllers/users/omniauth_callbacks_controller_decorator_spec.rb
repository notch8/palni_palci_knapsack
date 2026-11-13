# frozen_string_literal: true

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  let(:user) { create(:user) }
  let(:scope) { 'openid http://test.host/concern/cdls/abc-123' }
  let(:work_url) { 'http://test.host/uv/uv.html#?manifest=http://test.host/concern/cdls/abc-123/manifest' }

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
    request.env['omniauth.auth'] = OmniAuth::AuthHash.new(provider: 'saml', uid: '123')
    allow(User).to receive(:from_omniauth).and_return(user)
    allow(WorkAuthorization).to receive(:handle_signin_for!)
    allow(WorkAuthorization).to receive(:url_from).and_call_original
    allow(WorkAuthorization).to receive(:url_from).with(scope:, request: anything).and_return(work_url)
  end

  def expect_complete_page_redirecting_to(url)
    expect(controller).to receive(:render).with('complete', locals: { redirect_to_url: url }).and_call_original
  end

  %i[cas openid_connect saml].each do |action|
    describe "##{action}" do
      it 'signs in, grants CDL authorization and sends the user on to the requested work' do
        expect_complete_page_redirecting_to(work_url)

        get action, params: { id: 1, scope: }

        expect(WorkAuthorization).to have_received(:handle_signin_for!).with(user:, scope:)
        expect(controller.current_user).to eq(user)
        expect(session['user_return_to']).to eq('/uv/uv.html#?manifest=http://test.host/concern/cdls/abc-123/manifest')
      end

      it 'sends the user to the dashboard when the scope names no work' do
        expect_complete_page_redirecting_to(a_string_starting_with('/dashboard'))

        get action, params: { id: 1 }

        expect(controller.current_user).to eq(user)
        expect(session['user_return_to']).to be_nil
      end

      it 'redirects home with an error when the user cannot be saved' do
        allow(user).to receive(:persisted?).and_return(false)

        get action, params: { id: 1 }

        expect(controller.current_user).to be_nil
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to start_with('Not able to log in user.')
      end
    end
  end
end
