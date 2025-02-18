# frozen_string_literal: true

# OVERRIDE: MigrateResourcesJob to add error handling and logging.

module MigrateResourcesJobDecorator
  def perform(ids: [], models: ['AdminSet', 'Collection'])
    debugger
    if ids.blank?
      models.each do |model|
        model.constantize.find_each do |item|
          migrate(item.id)
        end
      end
    else
      ids.each do |id|
        migrate(id)
      end
    end
    raise errors.inspect if errors.present?
  end

  def errors
    @errors ||= []
  end

  def migrate(id)
    begin
      resource = Hyrax.query_service.find_by(id: id)
      
      if resource.wings?
        errors << "✅ Resource #{id} has already been converted"
        return
      end
      
      result = MigrateResourceService.new(resource: resource).call
      errors << result unless result.success?
      result
    rescue StandardError => e
      errors << "😭 Failed to migrate #{id}: #{e.message}"
    end
  end
end

MigrateResourcesJob.prepend(MigrateResourcesJobDecorator)