# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 to skip user keys with no matching User instead of raising, so a
# collection whose participants include a deleted (or never-copied) user still accepts works.
# Remove once the Hyrax fix reaches this knapsack through a Hyku bump.
module Hyrax
  module PermissionManagerDecorator
    private

    def update_users_for(mode:, users:)
      existing, missing = users.map(&:to_s).partition { |user| ::User.find_by_user_key(user) }
      Hyrax.logger.warn("Skipping #{mode} permission for missing users: #{missing.join(', ')}") if missing.any?

      super(mode:, users: existing)
    end
  end
end

Hyrax::PermissionManager.prepend(Hyrax::PermissionManagerDecorator)
