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

  describe '.without_default_locale' do
    before { I18n.locale = I18n.default_locale }

    it 'drops a trailing locale' do
      expect(described_class.without_default_locale('/catalog?q=x&locale=en')).to eq('/catalog?q=x')
    end

    it 'drops a leading locale and keeps the rest of the query' do
      expect(described_class.without_default_locale('/catalog?locale=en&q=x')).to eq('/catalog?q=x')
    end

    it 'drops the whole query when locale is the only parameter' do
      expect(described_class.without_default_locale('/stats/work/1?locale=en')).to eq('/stats/work/1')
    end

    it 'leaves other locales alone' do
      expect(described_class.without_default_locale('/catalog?locale=de')).to eq('/catalog?locale=de')
    end

    it 'leaves paths alone outside the default locale' do
      skip 'no non-default locale available' if non_default.nil?
      I18n.locale = non_default
      expect(described_class.without_default_locale('/catalog?locale=en')).to eq('/catalog?locale=en')
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
