class AddFileToAssets < ActiveRecord::Migration[5.0]
  def change
    add_column :assets, :file, :string
  end
end
