# frozen_string_literal: true

# OVERRIDE hyrax to fix job... errors seem to stop the job without raising any error
# - submit a job for each migration
# - add logging
# - add permission_template option
class MigrateResourcesJob < ApplicationJob
  # @param models [Array>>String] Array of ActiveFedora model names to migrate to valkyrie objects
  # @param ids [Array>>String or String] Array or string of ids to migrate to valkyrie objects
  # @param permission_template [Boolean] If true, migrate source_ids from all permission templates
  # defaults to AdminSet & Collection models if empty (when using rake task "migrate_collections")
  def perform(ids: [], models: ['AdminSet', 'Collection'], permission_template: false)
    if ids.is_a?(String) || ids.count == 1
      migrate(Array.wrap(ids).first)
    elsif permission_template == true
      Hyrax::PermissionTemplate.pluck(:source_id).each do |id|
          MigrateResourcesJob.perform_later(ids: [id.to_s])
      end
    elsif ids.count > 1
      ids.each do |id|
        MigrateResourceJob.perform_later(ids: [id.to_s])
      end
    else
      models.each do |model|
        model.constantize.find_each do |item|
          MigrateResourceJob.perform_later(ids: [item.id.to_s])
        end
      end
    end
  end

  def migrate(id)
    Rails.logger.info "🍀 Migrating resource #{id} in tenant #{Site.account.name}"
    resource = Hyrax.query_service.find_by(id: id)
    return unless resource.wings? # this resource has already been converted
    result = MigrateResourceService.new(resource: resource).call
    if result.success?
      Rails.logger.info "✅ Migrating resource #{id} successfully"
    else
      Rails.logger.info "🚫 Migrating #{id} failed to migrate - #{result}"
      raise result
    end
  end
end
