# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- delete alongside app/services/hyrax/stats_pruner.rb once this knapsack's Hyrax pin includes that PR
namespace :hyrax do
  namespace :stats do
    desc "Delete redundant zero-count rows from the stats cache tables (DRY_RUN=true to only report counts, BATCH_SIZE=n rows per batch)"
    task prune_zero_stats: :environment do
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN'])
      batch_size = (ENV['BATCH_SIZE'] || 50_000).to_i

      { FileViewStat => :file_id, FileDownloadStat => :file_id, WorkViewStat => :work_id }.each do |klass, id_column|
        Hyrax::StatsPruner.call(klass: klass, id_column: id_column, dry_run: dry_run, batch_size: batch_size)
      end
    end
  end
end
