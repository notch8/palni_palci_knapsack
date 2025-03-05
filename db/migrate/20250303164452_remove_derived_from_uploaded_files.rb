# frozen_string_literal: true
class RemoveDerivedFromUploadedFiles < ActiveRecord::Migration[6.1]
  def change
    return unless column_exists?(:uploaded_files, :derived)
    remove_column :uploaded_files, :derived, :boolean, default: false
  end
end
