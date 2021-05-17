class AddStatusToMandat < ActiveRecord::Migration[6.1]
  def change
    add_column :mandates, :status, :string
  end
end
