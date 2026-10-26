# frozen_string_literal: true
require 'google/cloud/errors'

# HYRAX-BACKPORT: samvera/hyrax#7676 (find every piece with `git grep -l HYRAX-BACKPORT`)
# Delete once the Hyku pin includes the merged fix: rescues Google errors on the stats pages.
module Hyrax
  module StatsControllerDecorator
    extend ActiveSupport::Concern

    prepended do
      rescue_from Google::Cloud::Error, with: :analytics_unavailable
    end

    def file
      super
      @stats.to_flot # load now so a Google failure is rescued here, not mid-render
    end

    private

    def analytics_unavailable(exception)
      Rails.logger.error "Analytics error: #{exception.message}"
      # Anyone who can read a work can open its stats; only admins get the setup steps.
      if analytics_admin?
        @analytics_error = analytics_error_details(exception)
      else
        @analytics_unavailable = true
      end
      if action_name == 'file'
        (@stats ||= Hyrax::FileUsage.new(params[:id])).without_analytics
      else
        @document ||= ::SolrDocument.find(params[:id])
        @pageviews = @downloads = Hyrax::Analytics::Results.new([])
      end
      render action_name
    end

    def analytics_admin?
      current_user.present? && (current_user.admin? || current_user.superadmin?)
    end

    def analytics_error_details(exception)
      type = exception.is_a?(Google::Cloud::PermissionDeniedError) ? 'permission' : 'general'
      scope = "hyrax.admin.analytics.errors.#{type}"
      { title: I18n.t('title', scope:),
        message: I18n.t('message', scope:),
        troubleshooting_steps: Array.wrap(I18n.t('troubleshooting_steps', scope:)),
        documentation_url: I18n.t('documentation_url', scope:) }
    end
  end
end

Hyrax::StatsController.prepend(Hyrax::StatsControllerDecorator)
