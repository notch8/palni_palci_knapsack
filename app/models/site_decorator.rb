# frozen_string_literal: true

# OVERRIDE Hyku -- Site.instance uses `first_or_create`, which is never
# memoized: every call is a fresh database round-trip. Profiling found a
# single /catalog page load calls Site.instance ~650-680 times, almost
# entirely through the `delegate :account, ..., to: :instance` line (the
# ubiquitous `Site.account` accessor), not through one obvious N+1 loop.
# Memoize per-request via RequestStore (already a transitive dependency
# here), the same way `current_account` is already memoized in
# ApplicationController/HykuHelper. RequestStore clears automatically at
# each request boundary via its own Rack middleware, which lines up with
# when Apartment re-resolves the tenant -- so there's no risk of a stale
# Site leaking across tenants on a reused Puma thread.
module SiteDecorator
  def instance
    RequestStore.store[:site_instance] ||= super
  end
end

Site.singleton_class.prepend(SiteDecorator)
