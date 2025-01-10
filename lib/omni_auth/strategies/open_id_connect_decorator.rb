# frozen_string_literal: true
module OmniAuth
  module Strategies
    ##
    # OVERRIDE to provide openid {#scope} based on the current session.
    #
    # @see https://github.com/notch8/palni-palci/issues/633
    module OpenIDConnectDecorator
      ##
      # override callback phase to fix issue where state is not required.
      # if require_state is false, it doesn't matter what is in the state param
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def callback_phase
        error = params['error_reason'] || params['error']
        error_description = params['error_description'] || params['error_reason']
        invalid_state = false unless options.require_state
        invalid_state = true if invalid_state.nil? && params['state'].to_s.empty?
        invalid_state = params['state'] != stored_state if invalid_state.nil?

        raise OmniAuth::Strategies::OpenIDConnect::CallbackError, error: params['error'], reason: error_description, uri: params['error_uri'] if error
        raise OmniAuth::Strategies::OpenIDConnect::CallbackError, error: :csrf_detected, reason: "Invalid 'state' parameter" if invalid_state

        return unless valid_response_type?

        options.issuer = issuer if options.issuer.blank?

        verify_id_token!(params['id_token']) if configured_response_type == 'id_token'
        discover!
        client.redirect_uri = redirect_uri

        return id_token_callback_phase if configured_response_type == 'id_token'

        client.authorization_code = authorization_code
        access_token
        super
      rescue OmniAuth::Strategies::OpenIDConnect::CallbackError => e
        fail!(e.error, e)
      rescue ::Rack::OAuth2::Client::Error => e
        fail!(e.response[:error], e)
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT => e
        fail!(:timeout, e)
      rescue ::SocketError => e
        fail!(:failed_to_connect, e)
      end

      ##
      # OVERRIDE
      # add debugging info
      # rubocop:disable Metrics/MethodLength
      def decode_id_token(id_token)
        decoded = JSON::JWT.decode(id_token, :skip_verification)
        algorithm = decoded.algorithm.to_sym

        validate_client_algorithm!(algorithm)

        keyset =
          case algorithm
          when :HS256, :HS384, :HS512
            secret
          else
            public_key
          end
        begin
          decoded.verify!(keyset)
        rescue JSON::JWS::VerificationFailed
          Rails.logger.error("omniauth: invalid jwt signature - keyset #{algorithm.inspect} - #{id_token.inspect} - #{keyset.inspect}")
        end

        ::OpenIDConnect::ResponseObject::IdToken.new(decoded)
      rescue JSON::JWK::Set::KidNotFound
        # If the JWT has a key ID (kid), then we know that the set of
        # keys supplied doesn't contain the one we want, and we're
        # done. However, if there is no kid, then we try each key
        # individually to see if one works:
        # https://github.com/nov/json-jwt/pull/92#issuecomment-824654949
        raise if decoded&.header&.key?('kid')

        decoded = decode_with_each_key!(id_token, keyset)

        raise unless decoded

        decoded
      end

      ##
      # OVERRIDE
      #
      # In OmniAuth, the options are a tenant wide configuration.  However, per
      # the client's controlled digitial lending (CDL) system, in the options we
      # use for authentication we must inclue the URL of the work that the
      # authenticating user wants to access.
      #
      # @note In testing, when the scope did not include the sample noted in the
      #       {#requested_work_url} method, the openid provider would return the
      #       status 200 (e.g. Success) and a body "Failed to get response from
      #       patron API"
      #
      # @return [Hash<Symbol,Object>]
      def options
        opts = super

        url = requested_work_url

        # WARNING! The order of the scope matters with the openid provider's implementation.
        #
        # Given the scope is `[:openid, url]`
        # When we provide the correct credentials to the openid provider
        # Then we get a "Failed to get response from patron API" on the openid provider
        #   and the hand shake process fails.
        #
        # Given the scope is `[url :openid]`
        # When we provide the correct credentials to the openid provider
        # Then we successfully complete the hand-shake
        #    and authorize the user into the Hyku instance.
        opts[:scope] = [url] + opts[:scope] if url.present? && !opts[:scope].include?(url)

        opts
      end

      ##
      # Why all of the hoops?  Because in conventional Open ID the scope's are hard-coded.  However,
      # we're using the requested URL as the scope.  And that value is getting lost during the auth
      # hand-shake.  It's in one of the following 2 places.
      #
      # @return [String] The URL of the work that was requested by the
      #         authenticating user.
      #
      # @note {#session} method is `@env['rack.session']`
      # @note {#env} method is the hash representation of the Rack environment.
      # @note {#request} method is the {#env} as a Rack::Request object
      #
      # @note The following URL is known to be acceptable for the reshare.commons-archive.org tenant:
      #
      #       https://reshare.palni-palci-staging.notch8.cloud/concern/cdls/74ebfc53-ee7c-4dc9-9dd7-693e4d840745
      #
      def requested_work_url
        request = ActionDispatch::Request.new(Rails.application.env_config.merge(env))
        request.cookie_jar[:reshare_url].presence ||
          session["user_return_to"].presence ||
          WorkAuthorization.url_from(scope: params['scope'], request:)
      end
    end
  end
end

OmniAuth::Strategies::OpenIDConnect.prepend(OmniAuth::Strategies::OpenIDConnectDecorator)
