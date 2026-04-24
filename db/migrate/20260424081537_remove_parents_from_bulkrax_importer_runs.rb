# frozen_string_literal: true

# This is a duplicate of a migration added in Bulkrax in https://github.com/samvera/bulkrax/pull/1183
# The migration is idempotent - adding it here allows us to deploy it to production more quickly.
class RemoveParentsFromBulkraxImporterRuns < ActiveRecord::Migration[5.2]
  def up
    remove_column :bulkrax_importer_runs, :parents, if_exists: true
  end

  def down
    add_column :bulkrax_importer_runs, :parents, :text, array: true, default: "{}", unless_exists: true
  end
end
