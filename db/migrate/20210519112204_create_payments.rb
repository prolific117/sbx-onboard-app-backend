class CreatePayments < ActiveRecord::Migration[6.1]
  def change
    create_table :payments do |t|
      t.string :status
      t.integer :amount
      t.integer :customer_id
      t.integer :mandate_id

      t.timestamps
    end
  end
end
