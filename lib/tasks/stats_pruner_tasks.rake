# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- remove alongside app/services/hyrax/stats_pruner.rb once this pin includes that PR
namespace :hyrax do
  namespace :stats do
    desc "Delete redundant zero-count rows from the stats cache tables (DRY_RUN=true to only report counts, BATCH_SIZE=n rows per batch)"
    # Run via `rake tenantize:task[hyrax:stats:prune_zero_stats]`, not bare -- this task is schema-agnostic and only touches whatever tenant is current.
    task prune_zero_stats: :environment do
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN'])
      batch_size = (ENV['BATCH_SIZE'] || 50_000).to_i

      { FileViewStat => :file_id, FileDownloadStat => :file_id, WorkViewStat => :work_id }.each do |klass, id_column|
        Hyrax::StatsPruner.call(klass:, id_column:, dry_run:, batch_size:)
      end
    end
  end
end
