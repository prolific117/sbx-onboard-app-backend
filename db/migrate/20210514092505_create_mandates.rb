class CreateMandates < ActiveRecord::Migration[6.1]
  def change
    create_table :mandates do |t|
      t.integer :customer_id
      t.string :mandate

      t.timestamps
    end
  end
end
