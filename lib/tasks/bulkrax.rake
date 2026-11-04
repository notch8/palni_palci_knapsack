# frozen_string_literal: true
namespace :bulkrax do
  desc "reclassify OerCsvParser's and EtdCsvParser's to CsvParser's"
  task single_csv_parser: :environment do
    Account.find_each do |account|
      puts "=============== updating #{account.name} ============"
      next if account.name == "search"
      switch!(account)

      begin
        Bulkrax::Exporter.find_each do |e|
          e.update(parser_klass: 'Bulkrax::CsvParser') if e.parser_klass == 'Bulkrax::OerCsvParser' || e.parser_klass == 'Bulkrax::EtdCsvParser'
        end
        Bulkrax::Importer.find_each do |e|
          e.update(parser_klass: 'Bulkrax::CsvParser') if e.parser_klass == 'Bulkrax::OerCsvParser' || e.parser_klass == 'Bulkrax::EtdCsvParser'
        end
        puts "=============== finished updating #{account.name} ============"
      rescue => e
        puts "(#{e.message})"
      end
    end
  end
end

namespace :bulkrax do
  desc 'Remove generated: true from descriptive fields in saved tenant mappings (DRY_RUN=true to preview)'
  task ungenerate_descriptive_fields: :environment do
    dry_run = ENV['DRY_RUN'] == 'true'
    Account.find_each do |account|
      next if account.name == 'search'

      changed = HykuKnapsack::BulkraxGeneratedFlagRemover.new(account, dry_run:).call
      verb = dry_run ? 'would update' : 'updated'
      puts changed.any? ? "#{account.name}: #{verb} #{changed.join(', ')}" : "#{account.name}: no change"
    rescue StandardError => e
      puts "#{account.name}: failed (#{e.class}: #{e.message})"
    end
  end
end
