# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7746
# Delete with Hyrax::DefaultLocalePathsDecorator.
RSpec.describe Hyrax::DefaultLocalePathsDecorator do
  around do |example|
    original_locale = I18n.locale
    example.run
    I18n.locale = original_locale
  end

  let(:non_default) { (I18n.available_locales - [I18n.default_locale]).first }

  describe '.url_locale' do
    it 'is nil in the default locale' do
      I18n.locale = I18n.default_locale
      expect(described_class.url_locale).to be_nil
    end

    it 'is the current locale otherwise' do
      skip 'no non-default locale available' if non_default.nil?
      I18n.locale = non_default
      expect(described_class.url_locale).to eq(non_default)
    end
  end

  describe 'renderer search links' do
    it 'leave ?locale= out of faceted links in the default locale' do
      I18n.locale = I18n.default_locale
      html = Hyrax::Renderers::FacetedAttributeRenderer.new(:keyword, ['history']).render
      expect(html).to include('/catalog?f')
      expect(html).not_to include('locale=')
    end

    it 'leave ?locale= out of linked search links in the default locale' do
      I18n.locale = I18n.default_locale
      html = Hyrax::Renderers::LinkedAttributeRenderer.new(:creator, ['Smith']).render
      expect(html).to include('/catalog?')
      expect(html).not_to include('locale=')
    end

    it 'keep a non-default locale on faceted links' do
      skip 'no non-default locale available' if non_default.nil?
      I18n.locale = non_default
      html = Hyrax::Renderers::FacetedAttributeRenderer.new(:keyword, ['history']).render
      expect(html).to include("locale=#{non_default}")
    end
  end
end
