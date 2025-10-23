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
    view.view_paths.unshift(HykuKnapsack::Engine.root.join('app', 'views'))
    allow(template).to receive(:render).and_call_original
    allow(template).to receive(:render).with({ partial: "splash/search_form" }).and_return('our_search_form')
    render
  end

  it 'renders the knapsack overlay' do
    expect(rendered).not_to include('our_search_form')
    expect(view.view_paths.first.path).to include('/app/samvera/app/views')

    expect(rendered).to include('Collaborative Repository')
  end
end
