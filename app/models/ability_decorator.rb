# frozen_string_literal: true
# OVERRIDE Bulkrax 9.3.5 permissions override
module AbilityDecorator
  def can_import_works?
    admin? || superadmin? # OVERRIDE until Bulkrax permissions is worked out can_create_any_work?
  end

  def can_export_works?
    admin? || superadmin? # OVERRIDE until Bulkrax permissions is worked out can_create_any_work?
  end
end

Ability.prepend(AbilityDecorator)
