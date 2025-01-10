# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token

    # rubocop:disable Metrics/AbcSize
    def callback
      logger.info("=@=@=@=@  auth: #{request.env['omniauth.auth']}, params: #{params.inspect}")

      @user = User.from_omniauth(request.env['omniauth.auth'])

      if @user.persisted?
        # https://github.com/notch8/palni-palci/issues/633
        WorkAuthorization.handle_signin_for!(user: @user, scope: params[:scope])

        # By default the sign_in_and_redirect method will look for a stored_location_for.  However,
        # we're seeing that the stored location seems to get lost.  So we'll rely on the presence of
        # the scope to handle this.
        #
        # Related to OmniAuth::Strategies::OpenIDConnectDecorator
        url = WorkAuthorization.url_from(scope: params[:scope], request:)
        store_location_for(:user, url) if url

        # We need to render a loading page here just to set the session properly
        # otherwise the logged in session gets lost during the redirect
        set_flash_message(:notice, :success, kind: params[:action]) if is_navigational_format?
        sign_in @user, event: :authentication # this will throw if @user is not activated

        # Given that we need to render the "complete" page, we need to inform that page about
        # where we want a JS-based redirect to go.
        render 'complete', locals: { redirect_to_url: url || hyrax.dashboard_path }
      else
        redirect_to root_path, flash: { error: "Not able to log in user. #{@user.errors.full_messages}" }
      end
    end
    alias cas callback
    alias openid_connect callback
    alias saml callback

    def passthru
      render status: :not_found, plain: 'Not found. Authentication passthru.'
    end

    def failure
      redirect_to root_path, flash: { error: 'Authentication Failed. Something is wrong with the SSO configuration.' }
    end
  end
end
