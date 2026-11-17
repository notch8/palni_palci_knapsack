# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Users::OmniauthCallbacksController#callback: grant CDL work authorization on sign-in and redirect to the requested work.
#   Client-specific, keep.
module Users
  module OmniauthCallbacksControllerDecorator
    # rubocop:disable Metrics/AbcSize
    def callback
      logger.info("=@=@=@=@  auth: #{request.env['omniauth.auth']}, params: #{params.inspect}")

      @user = User.from_omniauth(request.env['omniauth.auth'])

      if @user.persisted?
        # https://github.com/notch8/palni-palci/issues/633
        WorkAuthorization.handle_signin_for!(user: @user, scope: params[:scope])

        # The stored location gets lost across the SSO round trip, so the scope carries the work's URL.
        # Related to OmniAuth::Strategies::OpenIDConnectDecorator
        url = WorkAuthorization.url_from(scope: params[:scope], request:)
        store_location_for(:user, url) if url

        # Render instead of redirecting, or the signed-in session is lost.
        set_flash_message(:notice, :success, kind: params[:action]) if is_navigational_format?
        sign_in @user, event: :authentication # this will throw if @user is not activated
        render 'complete', locals: { redirect_to_url: url || hyrax.dashboard_path }
      else
        redirect_to root_path, flash: { error: "Not able to log in user. #{@user.errors.full_messages}" }
      end
    end
    # rubocop:enable Metrics/AbcSize

    # Hyku's aliases copied its own callback when they were declared, so they must be redeclared here.
    alias cas callback
    alias openid_connect callback
    alias saml callback
  end
end

Users::OmniauthCallbacksController.prepend(Users::OmniauthCallbacksControllerDecorator)
