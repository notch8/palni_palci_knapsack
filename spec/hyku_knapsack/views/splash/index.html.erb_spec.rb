# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'splash/index', type: :view do
  include Warden::Test::Helpers
  include Devise::Test::ControllerHelpers

  let(:account_a) { FactoryBot.create(:account) }
  let(:account_b) { FactoryBot.create(:account) }

  before do
    assign(:images, [])
    assign(:accounts, [account_a, account_b])
    engine_views = HykuKnapsack::Engine.root.join('app', 'views').to_s
    # View spec view may not have prepend_view_path; use controller so the view resolves templates from the engine
    controller.prepend_view_path(engine_views)
    allow(template).to receive(:render).and_call_original
    allow(template).to receive(:render).with({ partial: "splash/search_form" }).and_return('our_search_form')
    render
  end

  it 'renders the knapsack overlay' do
    expect(rendered).not_to include('our_search_form')
    expect(controller.view_paths.to_a.first.to_s).to include('app/views')

    expect(rendered).to include('Collaborative Repository')
  end
end
