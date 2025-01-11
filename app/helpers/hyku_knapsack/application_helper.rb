# frozen_string_literal: true

module HykuKnapsack
  module ApplicationHelper
    include Hyrax::OverrideHelperBehavior

    # OVERRIDE Hyrax::FileSetHelper#media_display_partial
    #
    # changed from hyrax 3.4.1 to change audio and video items to use default partial
    def media_display_partial(file_set)
      'hyrax/file_sets/media_display/' +
        if file_set.image?
          'image'
        elsif file_set.pdf?
          'pdf'
        elsif file_set.office_document?
          'office_document'
        else
          'default'
        end
    end

    ##
    # @return [String] the URL to use for searching across all tenants.
    #
    # @see .cross_tenant_search_host
    # @see https://github.com/notch8/palni-palci/issues/947
    def self.cross_tenant_search_url
      # Do not include the scheme (e.g. http or https) but instead let the browser apply the correct
      # scheme.
      "//#{cross_tenant_search_host}/catalog"
    end

    ##
    # @api private
    #
    # @return [String] the host (e.g. "search.hykucommons.org") for cross-tenant search.
    def self.cross_tenant_search_host
      # I'm providing quite a few fallbacks, as this URL is used on the first page you'll see in a
      # new Hyku instance.
      ENV["HYKU_CROSS_TENANT_SEARCH_HOST"].presence ||
        Account.where(search_only: true).limit(1).pick(:cname) ||
        "search.hykucommons.org"
    end
  end
end
