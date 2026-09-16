# frozen_string_literal: true
# OVERRIDE Hyrax -- current_version/current_schema_id re-query+re-parse the YAML profile column on every call; memoize per-request (~20% of work-show wall time in profiling).
module Hyrax
  module FlexibleSchemaDecorator
    def current_version
      current_record&.profile
    end

    def current_schema_id
      current_record&.id
    end

    private

    def current_record
      RequestStore.store[:flexible_schema_current] ||= order("created_at asc").last
    end
  end
end

Hyrax::FlexibleSchema.singleton_class.prepend(Hyrax::FlexibleSchemaDecorator)
