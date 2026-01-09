# frozen_string_literal: true

# Stop gap measure to redirect legacy pittir urls to their new Hyku locations

module HykuKnapsack
  class LegacyRedirectsController < ApplicationController
    def show
      legacy_id = params[:legacy_id]
      solr_doc = find_work_by_legacy_id(legacy_id)
      return raise ActionController::RoutingError, 'Not Found' if solr_doc.blank?

      work_id = solr_doc['id']
      model = solr_doc['has_model_ssim']&.first

      redirect_to "/concern/#{model.tableize}/#{work_id}", status: :moved_permanently
    end

    private

    def find_work_by_legacy_id(legacy_id)
      response = Hyrax::SolrService.get("identifier_tesim:\"https://d-scholarship.pitt.edu/#{legacy_id}\"", rows: 1)
      response.dig('response', 'docs')&.first
    rescue RSolr::Error::Http => e
      Rails.logger.error "Legacy ID not found: #{e.message}"
      nil
    end
  end
end
