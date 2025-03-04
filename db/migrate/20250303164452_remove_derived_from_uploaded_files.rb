class RemoveDerivedFromUploadedFiles < ActiveRecord::Migration[6.1]
  def change
    if column_exists?(:uploaded_files, :derived)
      remove_column :uploaded_files, :derived
    end
  end
end
