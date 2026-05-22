# frozen_string_literal: true

RSpec.describe 'Redirects catch-all route placement', type: :request do
  # The redirects catch-all route (defined in the consuming Hyku app's
  # routes.rb) must be the last application-defined route in the combined
  # route table — including any routes contributed by HykuKnapsack::Engine.
  #
  # Hyku has its own spec that verifies the catch-all is last within Hyku's
  # own routes.rb. This spec verifies the *knapsack-side* invariant: any
  # route added to HykuKnapsack::Engine.routes must not splice in after the
  # catch-all when the knapsack engine is mounted into the parent app.
  #
  # The catch-all only exists once Hyku is bumped to a version that
  # includes the redirects feature. Until then, these assertions skip
  # rather than fail, so existing knapsack work isn't blocked by an
  # upstream dependency.

  let(:all_routes) { Rails.application.routes.routes.to_a }
  let(:catch_all) { all_routes.find { |r| r.path.spec.to_s.include?('*alias_path') } }

  before do
    skip 'redirects catch-all route not present in this Hyku version' if catch_all.nil?
  end

  describe 'catch-all route configuration' do
    it 'routes to hyrax/redirects#show' do
      expect(catch_all.defaults[:controller]).to eq('hyrax/redirects')
      expect(catch_all.defaults[:action]).to eq('show')
    end

    it 'appears after every application-defined route, including knapsack engine routes' do
      catch_all_index = all_routes.index(catch_all)
      routes_after = all_routes[(catch_all_index + 1)..]
      app_routes_after = routes_after.reject do |r|
        path = r.path.spec.to_s
        path.start_with?('/rails/') || path == '/'
      end
      expect(app_routes_after).to be_empty,
                                  'Expected no application routes after the catch-all, but found: ' \
                                  "#{app_routes_after.map { |r| r.path.spec.to_s }.join(', ')}. " \
                                  'A new knapsack engine route may be splicing in after *alias_path.'
    end
  end

  describe 'knapsack engine routes take priority over the catch-all' do
    # These are the routes currently defined in HykuKnapsack::Engine
    # (config/routes.rb). If any of them resolve to the redirects
    # controller, the knapsack engine has been mounted in the wrong
    # position relative to the catch-all.

    it 'routes /id/eprint/<numeric> to legacy_redirects#show, not the catch-all' do
      route = Rails.application.routes.recognize_path('/id/eprint/12345', method: :get)
      expect(route[:controller]).to eq('hyku_knapsack/legacy_redirects')
      expect(route[:action]).to eq('show')
    end

    it 'routes /<numeric> to legacy_redirects#show, not the catch-all' do
      route = Rails.application.routes.recognize_path('/12345', method: :get)
      expect(route[:controller]).to eq('hyku_knapsack/legacy_redirects')
      expect(route[:action]).to eq('show')
    end
  end
end
