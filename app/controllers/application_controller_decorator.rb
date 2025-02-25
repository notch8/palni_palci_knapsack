# frozen_string_literal: true

module ApplicationControllerDecorator
  ##
  # OVERRIDE Hyrax::Controller#deny_access_for_anonymous_user
  #
  # We are trying to serve two types of users:
  #
  # - Admins
  # - Not-admins
  #
  # Given that admins are a small subset, we can train and document how they can sign in.  In other
  # words, favor workflows that impact the less trained folk to help them accomplish their tasks.
  #
  # Without this change, given the site had an SSO provider, when I (an unauthenticated user) went
  # to a private work, then it would redirect me to the `/user/sign_in` route.
  #
  # At that route I had the following option:
  #
  # 1. Providing a username and password
  # 2. Selecting one of the SSO providers to use for sign-in.
  #
  # The problem with this behavior was that a user who was given a Controlled Digital Lending (CDL)
  # URL would see a username/password and likely attempt to authenticate with their CDL
  # username/password (which was managed by the SSO provider).
  #
  # The end result is that the authentication page most likely would create confusion.
  #
  # With this function change, I'm setting things up such that when the application uses calls
  # `new_user_session_path` we make a decision on what URL to resolve.
  def deny_access_for_anonymous_user(exception, json_message)
    session['user_return_to'] = request.url
    respond_to do |wants|
      wants.html do
        # See ./app/views/single_signon/index.html.erb for our 1 provider logic.
        path = if IdentityProvider.exists?
                 main_app.single_signon_index_path
               else
                 main_app.new_user_session_path
               end
        redirect_to path, alert: exception.message
      end
      wants.json { render_json_response(response_type: :unauthorized, message: json_message) }
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def global_request_logging
    FileUtils.mkdir_p(Rails.root.join('log')) unless Dir.exist?(Rails.root.join('log'))
    rl = ActiveSupport::Logger.new(Rails.root.join('log', 'request.log'))
    return unless request.host&.match('blc.hykucommons')

    http_request_header_keys = request.headers.env.keys.select { |header_name| header_name.match("^HTTP.*|^X-User.*") }

    rl.error '*' * 40
    rl.error request.method
    rl.error request.url
    rl.error request.remote_ip
    rl.error ActionController::HttpAuthentication::Token.token_and_options(request)

    cookies[:time] = Time.current.to_s
    session[:time] = Time.current.to_s
    http_request_header_keys.each do |key|
      rl.error [format("%20s", key.to_s), ':', request.headers[key].inspect].join(" ")
    end
    rl.error '-' * 40 + ' params'
    params.to_unsafe_hash.each_key do |key|
      rl.error [format("%20s", key.to_s), ':', params[key].inspect].join(" ")
    end
    rl.error '-' * 40 + ' cookies'
    cookies.to_h.each_key do |key|
      rl.error [format("%20s", key.to_s), ':', cookies[key].inspect].join(" ")
    end
    rl.error '-' * 40 + ' session'
    session.to_h.each_key do |key|
      rl.error [format("%20s", key.to_s), ':', session[key].inspect].join(" ")
    end

    rl.error '*' * 40
  end
  # rubocop:enable Metrics/AbcSize

  def set_sentry_context
    Sentry.set_user(id: session[:current_user_id]) # Set user context
    Sentry.set_extras(params: params.to_unsafe_h, url: request.url) # Set extra context
  end
end

ApplicationController.before_action :set_sentry_context
ApplicationController.before_action :global_request_logging
ApplicationController.class_attribute :http_basic_auth_username, default: 'pals'
ApplicationController.class_attribute :http_basic_auth_password, default: 'pals'
ApplicationController.prepend(ApplicationControllerDecorator)
