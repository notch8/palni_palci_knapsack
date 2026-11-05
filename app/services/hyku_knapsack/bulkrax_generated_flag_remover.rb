# frozen_string_literal: true

module HykuKnapsack
  class BulkraxGeneratedFlagRemover
    FIELDS = %w[
      abstract
      additional_information
      alternative_title
      bibliographic_citation
      rights_notes
      rights_statement
      source
    ].freeze

    SETTING = 'bulkrax_field_mappings'

    def initialize(account, dry_run: false)
      @account = account
      @dry_run = dry_run
    end

    # Returns the "Parser.field" entries that had the flag.
    def call
      stored = @account.settings[SETTING]
      return [] if stored.blank?

      mappings = JSON.parse(stored)
      changed = strip_flags(mappings)
      persist(mappings) if changed.any? && !@dry_run
      changed
    end

    private

    def strip_flags(mappings)
      mappings.flat_map do |parser, fields|
        next [] unless fields.is_a?(Hash)

        FIELDS.filter_map do |field|
          config = fields[field]
          # Bulkrax drops any field whose flag is truthy, so a stored "false" string still hides it.
          next unless config.is_a?(Hash) && config.key?('generated')

          config.delete('generated')
          "#{parser}.#{field}"
        end
      end
    end

    def persist(mappings)
      @account.bulkrax_field_mappings = JSON.pretty_generate(mappings)
      @account.save!
    end
  end
end
