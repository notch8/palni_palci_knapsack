# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7746 (find every piece with `git grep -l HYRAX-BACKPORT`)
# Temporary hotfix; delete this file once the Hyku pin includes the merged upstream fix.
# OVERRIDE Hyrax 1489c95: leave the default locale out of the paths these presenters and renderers
# build, so robots.txt's `Disallow: /*locale=` stops blocking crawlers (#948).
module Hyrax
  module DefaultLocalePathsDecorator
    def self.url_locale
      I18n.locale unless I18n.locale == I18n.default_locale
    end

    module AdminSetPresenter
      def show_path
        Hyrax::Engine.routes.url_helpers.admin_admin_set_path(id, locale: DefaultLocalePathsDecorator.url_locale)
      end
    end

    module CollectionPresenter
      def show_path
        Hyrax::Engine.routes.url_helpers.dashboard_collection_path(id, locale: DefaultLocalePathsDecorator.url_locale)
      end
    end

    module FileSetPresenter
      def stats_path
        Hyrax::Engine.routes.url_helpers.stats_file_path(self, locale: DefaultLocalePathsDecorator.url_locale)
      end
    end

    module WorkShowPresenter
      def stats_path
        Hyrax::Engine.routes.url_helpers.stats_work_path(self, locale: DefaultLocalePathsDecorator.url_locale)
      end
    end

    module FacetedAttributeRenderer
      private

      def search_path(value)
        Rails.application.routes.url_helpers.search_catalog_path(
          "f[#{search_field}][]": value, locale: DefaultLocalePathsDecorator.url_locale
        )
      end
    end

    module LinkedAttributeRenderer
      private

      def search_path(value)
        Rails.application.routes.url_helpers.search_catalog_path(
          search_field: search_field, q: ERB::Util.h(value), locale: DefaultLocalePathsDecorator.url_locale
        )
      end
    end
  end
end

Hyrax::AdminSetPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::AdminSetPresenter)
Hyrax::CollectionPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::CollectionPresenter)
Hyrax::FileSetPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::FileSetPresenter)
Hyrax::WorkShowPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::WorkShowPresenter)
Hyrax::Renderers::FacetedAttributeRenderer.prepend(Hyrax::DefaultLocalePathsDecorator::FacetedAttributeRenderer)
Hyrax::Renderers::LinkedAttributeRenderer.prepend(Hyrax::DefaultLocalePathsDecorator::LinkedAttributeRenderer)
