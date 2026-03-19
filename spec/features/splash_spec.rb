# frozen_string_literal: true

# NOTE: If want to run spec in broweser, you have to set "js: true"
RSpec.describe "The splash page", type: :feature, clean: true, multitenant: true do
  around do |example|
    original = ENV['HYKU_ADMIN_ONLY_TENANT_CREATION']
    ENV['HYKU_ADMIN_ONLY_TENANT_CREATION'] = "true"
    default_host = Capybara.default_host
    Capybara.default_host = Capybara.app_host || "http://#{Account.admin_host}"
    example.run
    Capybara.default_host = default_host
    ENV['HYKU_ADMIN_ONLY_TENANT_CREATION'] = original
  end

  it "shows the page, displaying the Hyku for Consortia content" do
    visit '/'
    expect(page).to have_content 'Collaborative Repository'

    within '.splash-footer-links' do
      expect(page).to have_link 'About'
      expect(page).to have_link 'Contact'
    end
  end
end
