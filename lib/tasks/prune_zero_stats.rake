# frozen_string_literal: true

# Backport of samvera/hyku#3331 - remove once the hyrax-webapp pin includes it.
namespace :hyku do
  desc "Delete redundant zero-count rows from the stats cache tables (FileViewStat, FileDownloadStat, " \
       "WorkViewStat) across all tenants, keeping the newest zero row per object (Hyrax::StatsPruner, " \
       "samvera/hyrax#7649). A tenant that fails is logged and skipped; the run exits non-zero at the end listing them. ENV: BATCH_SIZE (default 50000), DRY_RUN (default false)"
  task prune_zero_stats: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))
    batch_size = ENV.fetch('BATCH_SIZE', 50_000).to_i
    targets = { FileViewStat => :file_id, FileDownloadStat => :file_id, WorkViewStat => :work_id }

    failed = []

    Account.find_each do |account|
      Apartment::Tenant.switch(account.tenant) do
        targets.each do |klass, id_column|
          Rails.logger.info("hyku:prune_zero_stats - #{account.cname}: pruning #{klass}")
          Hyrax::StatsPruner.call(klass:, id_column:, dry_run:, batch_size:)
        end
      end
    rescue StandardError => e
      failed << account.cname
      Rails.logger.error("hyku:prune_zero_stats - #{account.cname} failed: #{e.class}: #{e.message}")
    end

    abort("hyku:prune_zero_stats - failed for: #{failed.join(', ')}") if failed.any?
  end
end
