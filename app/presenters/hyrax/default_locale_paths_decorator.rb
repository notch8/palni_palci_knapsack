# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7746 (find every piece with `git grep -l HYRAX-BACKPORT`)
# Temporary hotfix; delete this file once the Hyku pin includes the merged upstream fix.
# OVERRIDE Hyrax 1489c95: drop the default locale from the paths these presenters and renderers
# build, so robots.txt's `Disallow: /*locale=` stops blocking crawlers (#948). Wraps super rather
# than copying each method, so it is a no-op on a Hyrax that already includes the fix.
module Hyrax
  module DefaultLocalePathsDecorator
    def self.without_default_locale(path)
      return path unless I18n.locale == I18n.default_locale

      locale = Regexp.escape(I18n.default_locale.to_s)
      path.sub(/([?&])locale=#{locale}(&|\z)/) { Regexp.last_match(2).empty? ? '' : Regexp.last_match(1) }
    end

    module ShowPath
      def show_path
        DefaultLocalePathsDecorator.without_default_locale(super)
      end
    end

    module StatsPath
      def stats_path
        DefaultLocalePathsDecorator.without_default_locale(super)
      end
    end

    module SearchPath
      private

      def search_path(*)
        DefaultLocalePathsDecorator.without_default_locale(super)
      end
    end
  end
end

Hyrax::AdminSetPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::ShowPath)
Hyrax::CollectionPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::ShowPath)
Hyrax::FileSetPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::StatsPath)
Hyrax::WorkShowPresenter.prepend(Hyrax::DefaultLocalePathsDecorator::StatsPath)
Hyrax::Renderers::FacetedAttributeRenderer.prepend(Hyrax::DefaultLocalePathsDecorator::SearchPath)
Hyrax::Renderers::LinkedAttributeRenderer.prepend(Hyrax::DefaultLocalePathsDecorator::SearchPath)
