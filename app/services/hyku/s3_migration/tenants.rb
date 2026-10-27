# frozen_string_literal: true

# TEMPORARY(s3-migration): remove once the Hyku pin includes samvera/hyku#3393 (then use tenantize:task
# instead), together with every other file carrying this tag.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

module Hyku
  module S3Migration
    # Runs a block inside each tenant (or the given ones, by cname), skipping search-only accounts.
    # A failure in one tenant is reported to on_error and the loop carries on.
    #
    # Stopgap for the pinned Hyku, whose tenantize:task only repoints Solr/Fedora/Redis and leaves the
    # default database schema active. Apartment's switch also repoints those endpoints, through the
    # :switch callback in config/initializers/apartment.rb. Delete this and use tenantize:task once the
    # Hyku pin includes samvera/hyku#3393.
    module Tenants
      # @return [Array<String>] cnames of tenants that raised
      def self.each(tenants: [], on_error: ->(_account, _error) {})
        accounts = tenants.present? ? Account.where(cname: tenants) : Account.all
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
end
