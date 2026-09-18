# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 backport of samvera/hyrax#7649 -- remove alongside app/services/hyrax/stats_pruner.rb once this pin includes that PR
namespace :hyrax do
  namespace :stats do
    desc "Delete redundant zero-count rows from the stats cache tables for every tenant (DRY_RUN=true to only report counts, BATCH_SIZE=n rows per batch)"
    # Iterates tenants itself, via switch!(account) -- tenantize:task's account.switch only swaps Solr/Fedora/Redis/host, never the Apartment/Postgres tenant.
    task prune_zero_stats: :environment do
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN'])
      batch_size = (ENV['BATCH_SIZE'] || 50_000).to_i

      Account.find_each do |account|
        next if account.name == "search"
        switch!(account)

        begin
          { FileViewStat => :file_id, FileDownloadStat => :file_id, WorkViewStat => :work_id }.each do |klass, id_column|
            Hyrax::StatsPruner.call(klass:, id_column:, dry_run:, batch_size:, tenant: account.cname)
          end
        rescue StandardError => e
          Hyrax.logger.error("hyrax:stats:prune_zero_stats: #{account.cname} failed: #{e.message}")
        end
      end
    end
  end
end
