class AddTitleToFileResources < ActiveRecord::Migration[8.0]
  def change
    add_column :file_resources, :title, :string
  end
end
