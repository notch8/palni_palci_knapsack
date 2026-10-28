# frozen_string_literal: true

module Hyku
  # Runs a block inside each tenant (or the given ones, by cname), skipping search-only accounts.
  # A failure in one tenant goes to on_error and the loop carries on.
  #
  # The pinned Hyku's tenantize:task only repoints Solr/Fedora/Redis and leaves the default database schema
  # active, so it cannot run the s3_migration tasks. Apartment's switch does both, through the :switch callback in
  # config/initializers/apartment.rb. Once the Hyku pin includes samvera/hyku#3393, use tenantize:task instead.
  module EachTenant
    # Raised when require_tenants is set and no tenants were named.
    class TenantsRequired < ArgumentError; end

    # @param require_tenants [Boolean] refuse to run on every tenant: tenants must be named
    # @return [Array<String>] cnames of the tenants that raised
    def self.call(tenants: [], require_tenants: false, on_error: ->(_account, _error) {})
      raise TenantsRequired, 'name the tenants to run on' if require_tenants && tenants.blank?

      accounts = tenants.present? ? Account.tenants(tenants) : Account.all
      failed = []
      accounts.find_each do |account|
        next if skip?(account)

        Apartment::Tenant.switch(account.tenant) { yield account }
      rescue StandardError => e
        on_error.call(account, e)
        failed << account.cname
      end
      failed
    end

    def self.skip?(account)
      account.respond_to?(:search_only?) ? account.search_only? : account.name == 'search'
    end
  end
end
