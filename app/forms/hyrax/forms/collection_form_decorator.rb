# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 Hyrax::Forms::CollectionForm: add the subtitle and hide role grants on the ActiveFedora collection form.
#   No longer used; remove in a follow-up to #820.
module Hyrax
  module Forms
    # Add new method to filter out access_grants for Collection Roles and Work Roles
    # for Collections and AdminSets, respectively. We do this because access_grants
    # for Roles should never be allowed to be removed.
    #
    # @see app/views/hyrax/dashboard/collections/_form_share_table.html.erb
    module CollectionFormDecorator
      def self.decorate(base)
        base.prepend(self)

        # Using += results in a duplicate :collection_subtitle being added
        base.terms |= [:collection_subtitle]
      end

      def primary_terms
        [:title, :collection_subtitle, :description]
      end

      def filter_access_grants_by_access(access)
        roles_to_filter = ::RolesService::COLLECTION_ROLES + ::RolesService::WORK_ROLES
        filtered_access_grants = permission_template.access_grants.select(&access)
        filtered_access_grants.reject! { |ag| roles_to_filter.include?(ag.agent_id) }

        filtered_access_grants || []
      end
    end
  end
end

Hyrax::Forms::CollectionFormDecorator.decorate(Hyrax::Forms::CollectionForm)
