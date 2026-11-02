# frozen_string_literal: true

# Runs the s3_migration:* tasks once per tenant: `rake hyku:s3_migration:report`, and so on.
# Limit to some tenants with tenants="a.example.com b.example.com". Options such as APPLY=true and LIMIT=5 pass through.
# migrate, quarantine, rollback and purge change things, so they refuse to run without tenants=: do one tenant,
# check it, then the next. report and verify are read-only and default to every tenant.
# Once the Hyku pin includes samvera/hyku#3393, `rake "tenantize:task[s3_migration:report]"` does the same.
namespace :hyku do
  namespace :s3_migration do
    named_tenants_only = %w[migrate quarantine rollback purge].freeze

    %w[migrate verify report quarantine rollback purge].each do |name|
      desc "Run s3_migration:#{name} in each tenant (tenants=\"a.example.com b.example.com\" " \
           "#{named_tenants_only.include?(name) ? 'required' : 'to limit'})"
      task name => :environment do
        gem_task = Rake::Task["s3_migration:#{name}"]
        on_error = ->(account, error) { puts "  TENANT ERROR #{account.cname} - #{error.class}: #{error.message}" }

        failed = Hyku::EachTenant.call(tenants: ENV.fetch('tenants', '').split, on_error:,
                                       require_tenants: named_tenants_only.include?(name)) do |account|
          puts "=== Tenant: #{account.cname} ==="
          gem_task.reenable
          gem_task.invoke
        end
        abort "\nTenants that failed (rerun with tenants=\"<cname>\"): #{failed.join(', ')}" if failed.any?
      rescue Hyku::EachTenant::TenantsRequired
        abort "hyku:s3_migration:#{name} changes data, so name the tenants: tenants=\"a.example.com\". " \
              'Run one, check it, then the next.'
      end
    end
  end
end
