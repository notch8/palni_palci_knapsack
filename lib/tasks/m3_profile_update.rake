# frozen_string_literal: true

# Rake task for inspecting and updating tenants' M3 metadata profile via
# HykuKnapsack::M3ProfileUpdater.
#
# One task takes four positional arguments:
#
#   name     - the tenant's Account.name, or the literal string "all" to
#              iterate every account except the "search" cross-tenant
#              search account (which has no profile)
#   action   - "audit" (no writes, reports what would change) or "apply"
#              (carries out the change per the revision arg)
#   revision - "update" (mutate the existing profile row in place, default)
#              or "add" (create a new profile revision row; existing works
#              keep pointing at the prior row)
#   report   - truthy ("true", "yes", "1") writes a per-tenant YAML report
#              to tmp/imports/m3_profile_reports/. Omit or pass anything
#              falsy for terse stdout summary only
#
# Examples:
#
#   # Audit what would change in place on one tenant
#   bundle exec rake hyku_knapsack:m3_profile_for_tenant[demo,audit,update]
#
#   # Apply the in-place changes on one tenant with a report
#   bundle exec rake hyku_knapsack:m3_profile_for_tenant[demo,apply,update,true]
#
#   # Audit what would happen if we created a new revision row instead
#   bundle exec rake hyku_knapsack:m3_profile_for_tenant[demo,audit,add,true]
#
#   # Apply: create a new revision row on one tenant
#   bundle exec rake hyku_knapsack:m3_profile_for_tenant[demo,apply,add,true]
#
#   # Across all tenants
#   bundle exec rake hyku_knapsack:m3_profile_for_tenant[all,audit,update,true]
#   bundle exec rake hyku_knapsack:m3_profile_for_tenant[all,apply,update,true]
#
# In zsh quote the task name so brackets aren't glob-interpreted:
#
#   bundle exec rake 'hyku_knapsack:m3_profile_for_tenant[demo,apply,update,true]'
#
# Output legend:
#   🚫 nothing to change         (service status: :no_changes)
#   ✅ successful apply          (service status: :initialized, :updated, :added)
#   ⚠️  review needed             (service status: :will_update, :will_add,
#                                  :would_initialize, :needs_review,
#                                  :partial_no_op)
#   🐛 failure                    (service status: :error, or rake-level
#                                  exception)
#
# ---------------------------------------------------------------------------
# Running in staging
# ---------------------------------------------------------------------------
#
# Choosing a revision strategy:
#
#   update  - Mutates the latest Hyrax::FlexibleSchema row in place. The row
#             id does not change, so every existing work on the tenant picks
#             up the new field definitions on its next load. A YAML backup
#             of the prior profile is written to
#             tmp/imports/m3_profile_backups/ before any mutation.
#             This is the recommended path for #597, because the goal is to
#             apply form-side and view-side fixes to every existing work
#             without per-work edits and without a reindex.
#
#   add     - Creates a new Hyrax::FlexibleSchema row with the updated
#             profile. Existing works keep pointing at the prior row id, so
#             nothing changes for already-persisted works. New works
#             created after the apply use the new row. No backup is written
#             (nothing is overwritten). Use this when you want a clean
#             revision boundary, not a fleet-wide in-place fix.
#
# Recommended staging sequence:
#
#   1. Audit one tenant in :update mode and inspect the report:
#
#        bundle exec rake 'hyku_knapsack:m3_profile_for_tenant[demo,audit,update,true]'
#
#      The summary line shows the per-descriptor breakdown
#      (will_update, will_create_path, already_correct, already_present,
#      already_absent, unexpected, path_missing). A status of :will_update
#      means apply would do work. :unexpected_value or :path_missing on
#      any descriptor means the tenant's profile diverges from the on-disk
#      default — investigate before applying.
#
#   2. Audit every tenant to catch divergence across the fleet:
#
#        bundle exec rake 'hyku_knapsack:m3_profile_for_tenant[all,audit,update,true]'
#
#      Each tenant gets its own report file under
#      tmp/imports/m3_profile_reports/<tenant>-<timestamp>-audit-update.yaml.
#      Skim for tenants reporting :needs_review or :partial_no_op.
#
#   3. Apply against one tenant first to confirm the result:
#
#        bundle exec rake 'hyku_knapsack:m3_profile_for_tenant[demo,apply,update,true]'
#
#      Spot-check via Rails console in that tenant (see service-level docs
#      and #597 verification notes) and on the work edit / show pages.
#
#   4. Apply across the fleet:
#
#        bundle exec rake 'hyku_knapsack:m3_profile_for_tenant[all,apply,update,true]'
#
#      Errors on one tenant do not stop the iteration — each tenant runs
#      in its own transaction; failures are logged with the 🐛 prefix.
#
# Backups and reports:
#
#   - Backups (only written on apply/update with a prior row present):
#       tmp/imports/m3_profile_backups/<tenant>-<YYYYMMDD-HHMMSS>.yaml
#
#   - Reports (only written when the 4th arg is truthy):
#       tmp/imports/m3_profile_reports/<tenant>-<YYYYMMDD-HHMMSS>-<action>-<revision>.yaml
#
#   Both paths live under tmp/imports/ specifically because that directory
#   is not wiped as aggressively as the rest of tmp/. Copy off-host if you
#   need a longer-term record.
#
# Reading a report file:
#
#   Each report YAML contains a `changes:` array with one entry per
#   descriptor. Each entry has a `path:` (dotted profile location), a
#   `status:` (Ruby symbol — note the leading colon when grepping), and
#   a `current:` / `new:` (or `value:` for array mutations) showing
#   before/after. The statuses to investigate fall into three buckets:
#
#     Investigate (something needs human judgement):
#       :path_missing      — property doesn't exist on this tenant at all
#       :unexpected_value  — current value is neither expected nor new
#
#     Informational (apply will do work here, no concern):
#       :will_update       — value differs from desired; apply will set it
#       :will_create_path  — intermediate sub-key missing; apply will create
#       :updated           — apply mode wrote this descriptor
#
#     Safe to ignore (already in desired state):
#       :already_correct   — scalar already matches
#       :already_present   — array already includes value
#       :already_absent    — array already excludes value
#
#   Useful grep commands (from inside the web container, with TENANT and
#   TIMESTAMP filled in from the path the rake task printed):
#
#     # Property paths that don't exist on this tenant — start here.
#     grep -B 8 -A 2 'status: :path_missing' \
#       tmp/imports/m3_profile_reports/<TENANT>-<TIMESTAMP>-<action>-<revision>.yaml
#
#     # Descriptors with surprising current values — also worth investigating.
#     grep -B 8 -A 2 'status: :unexpected_value' \
#       tmp/imports/m3_profile_reports/<TENANT>-<TIMESTAMP>-<action>-<revision>.yaml
#
#     # Quick counts by status (sanity-check against the summary line).
#     grep '^  status:' \
#       tmp/imports/m3_profile_reports/<TENANT>-<TIMESTAMP>-<action>-<revision>.yaml \
#       | sort | uniq -c
#
#     # All descriptor paths in this report, one per line.
#     grep '^- path:' \
#       tmp/imports/m3_profile_reports/<TENANT>-<TIMESTAMP>-<action>-<revision>.yaml
#
#   YAML serializes Ruby symbols with a leading colon, so the grep pattern
#   must include it: `status: :path_missing`, not `status: path_missing`.
#
# Idempotency:
#
#   Both audit and apply are safe to re-run. On a second run with no
#   pending changes the summary reports :no_changes (🚫) and no DB write
#   happens. The :add revision additionally skips creating a duplicate
#   row when the latest row already matches the desired state.
#
# Rollback (revision :update only):
#
#   To restore a tenant, load the corresponding backup YAML into the
#   latest Hyrax::FlexibleSchema row from a Rails console scoped to that
#   tenant:
#
#     Apartment::Tenant.switch(<tenant>) do
#       schema = Hyrax::FlexibleSchema.order(:created_at).last
#       schema.profile = YAML.safe_load_file(
#         Rails.root.join('tmp/imports/m3_profile_backups/<tenant>-<ts>.yaml')
#       )
#       schema.save!
#     end
#
#   There is no per-row version history beyond these backups, so keep the
#   backup files around until the change has been validated in production.
#
# Reindex:
#
#   No reindex is needed for the descriptors currently in CHANGES — every
#   mutation is form-side or view-side (cardinality, form.required, view:
#   block, editor_only / admin_only indexing flags that are filtered
#   before reaching Solr). If future descriptors touch indexing in a way
#   that changes to_solr output, a reindex will be required separately;
#   this task does not enqueue one.
#
# Web worker restart:
#
#   Not required. Hyrax::Flexibility#load re-queries the latest
#   FlexibleSchema row on every object instantiation and
#   Hyrax::M3SchemaLoader re-fetches the profile from the DB on every
#   call — there is no process-level cache to invalidate, so the next
#   request after the apply observes the new field rules automatically.
namespace :hyku_knapsack do
  desc 'Audit or apply M3 profile changes for one tenant or all (args: name|"all", "audit"|"apply", "update"|"add", report?)'
  task :m3_profile_for_tenant, %i[name action revision report] => :environment do |_cmd, args|
    raise ArgumentError, 'Missing required argument: name (or "all")' if args[:name].blank?
    raise ArgumentError, 'Missing required argument: action ("audit" or "apply")' if args[:action].blank?
    raise ArgumentError, 'Missing required argument: revision ("update" or "add")' if args[:revision].blank?

    M3ProfileTaskRunner.new(
      name: args[:name],
      action: args[:action].to_sym,
      revision: args[:revision].to_sym,
      report: M3ProfileTaskRunner.truthy?(args[:report])
    ).run
  end
end

# Coordinates M3ProfileUpdater invocations across tenants. With name="all",
# iterates every Account (skipping the "search" cross-tenant aggregation
# account, which has no profile). Otherwise resolves the single tenant
# by Account.name and runs against it. Matches the iteration style used
# elsewhere in this project (see lib/tasks/bulkrax.rake) —
# Account.find_each + switch!.
# rubocop:disable Metrics/ClassLength
class M3ProfileTaskRunner
  # Resolved lazily — Rails isn't loaded at rake-file evaluation time.
  def self.default_report_dir
    Rails.root.join('tmp', 'imports', 'm3_profile_reports')
  end

  SKIP_ACCOUNT_NAMES = %w[search].freeze

  STATUS_EMOJI = {
    no_changes: '🚫',
    initialized: '✅',
    updated: '✅',
    added: '✅',
    will_update: '⚠️',
    will_add: '⚠️',
    would_initialize: '⚠️',
    needs_review: '⚠️',
    partial_no_op: '⚠️',
    error: '🐛'
  }.freeze
  EXCEPTION_EMOJI = '🐛'
  UNKNOWN_EMOJI = '⚠️'

  VALID_ACTIONS = %i[audit apply].freeze
  VALID_REVISIONS = %i[update add].freeze

  def self.truthy?(value)
    %w[true yes 1 report].include?(value.to_s.strip.downcase)
  end

  def initialize(name:, action:, revision:, report:)
    raise ArgumentError, "Unknown action: #{action.inspect}" unless VALID_ACTIONS.include?(action)
    raise ArgumentError, "Unknown revision: #{revision.inspect}" unless VALID_REVISIONS.include?(revision)
    @name = name
    @action = action
    @revision = revision
    @report = report
  end

  def run
    if @name.to_s.casecmp('all').zero?
      run_all
    else
      run_single(@name)
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  private

  def run_all
    Account.find_each do |account|
      next if SKIP_ACCOUNT_NAMES.include?(account.name)
      run_for(account)
    end
  end

  def run_single(name)
    account = Account.find_by(name:)
    if account.nil?
      warn "No account matched name=#{name.inspect}"
      return
    end
    run_for(account)
  end

  def run_for(account)
    puts "=============== M3 profile #{@action}/#{@revision} for #{account.name} ==============="
    switch!(account)

    begin
      report = run_service
      puts summary_line(report, account)
      write_report_file(report) if @report
    rescue StandardError => e
      puts "#{EXCEPTION_EMOJI} [hyku_knapsack:m3_profile #{@action}/#{@revision}] tenant=#{account.cname} status=exception class=#{e.class} message=#{e.message.inspect}"
    end

    puts "=============== finished #{@action}/#{@revision} for #{account.name} ==============="
  end

  def run_service
    HykuKnapsack::M3ProfileUpdater.new(action: @action, revision: @revision).call
  end

  def summary_line(report, account)
    emoji = STATUS_EMOJI.fetch(report[:status], UNKNOWN_EMOJI)
    counts = report[:changes].group_by { |c| c[:status] }.transform_values(&:count)
    parts = [
      emoji,
      "[hyku_knapsack:m3_profile #{@action}/#{@revision}]",
      "tenant=#{report[:tenant] || account.cname}",
      "status=#{report[:status]}",
      "schema=#{report[:schema_id] || 'none'}",
      "descriptors=#{report[:changes].size}"
    ]
    parts << "new_schema=#{report[:new_schema_id]}" if report[:new_schema_id]
    parts << "updated=#{counts[:updated]}" if counts[:updated]&.positive?
    parts << "will_update=#{counts[:will_update]}" if counts[:will_update]&.positive?
    parts << "will_create_path=#{counts[:will_create_path]}" if counts[:will_create_path]&.positive?
    parts << "already_correct=#{counts[:already_correct]}" if counts[:already_correct]&.positive?
    parts << "already_present=#{counts[:already_present]}" if counts[:already_present]&.positive?
    parts << "already_absent=#{counts[:already_absent]}" if counts[:already_absent]&.positive?
    parts << "unexpected=#{counts[:unexpected_value]}" if counts[:unexpected_value]&.positive?
    parts << "path_missing=#{counts[:path_missing]}" if counts[:path_missing]&.positive?
    parts << "schema_initialized=true" if report[:schema_initialized]
    parts << "backup=#{report[:backup_path]}" if report[:backup_path]
    parts << "errors=#{report[:validation_errors].size}" if report[:validation_errors]&.any?
    parts.join(' ')
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def write_report_file(report)
    dir = self.class.default_report_dir
    FileUtils.mkdir_p(dir)
    timestamp = Time.zone.now.strftime('%Y%m%d-%H%M%S')
    filename = "#{report[:tenant]}-#{timestamp}-#{@action}-#{@revision}.yaml"
    path = dir.join(filename)
    File.write(path, YAML.dump(report.deep_stringify_keys))
    puts "  Report written to: #{path}"
  end
end
# rubocop:enable Metrics/ClassLength
