# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::Engine do
  describe 'translations' do
    it "win over a key Hyku's own locales define once boot reorders Hyku's" do
      files = [Rails.root.join('config', 'application.rb').to_s, described_class.root.join('lib', 'hyku_knapsack', 'engine.rb').to_s]
      ActiveSupport.instance_variable_get(:@load_hooks)[:after_initialize].map(&:first)
                   .select { |hook| files.include?(hook.source_location.first) }
                   .each { |hook| Rails.application.instance_exec(Rails.application, &hook) }

      expect(I18n.t('hyrax.product_name')).to eq 'Hyku Commons'
    end

    it "still win after a development reload re-runs Hyku's to_prepare" do
      Rails.application.config.to_prepare_blocks.each(&:call)

      expect(I18n.t('hyrax.product_name')).to eq 'Hyku Commons'
    end
  end
end
