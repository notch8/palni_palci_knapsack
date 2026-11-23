# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7746
# Delete with the default_url_options override in ApplicationControllerDecorator.
RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: 'ok'
    end
  end

  around do |example|
    original_locale = I18n.locale
    example.run
    I18n.locale = original_locale
  end

  describe '#default_url_options' do
    it 'omits :locale in the default locale' do
      I18n.locale = I18n.default_locale
      expect(controller.default_url_options).not_to have_key(:locale)
    end

    it 'keeps a non-default locale, and does not leak it into later requests' do
      non_default = (I18n.available_locales - [I18n.default_locale]).first
      skip 'no non-default locale available' if non_default.nil?

      I18n.locale = non_default
      expect(controller.default_url_options[:locale]).to eq(non_default)

      I18n.locale = I18n.default_locale
      expect(controller.default_url_options).not_to have_key(:locale)
    end
  end
end
