class CreateAddresses < ActiveRecord::Migration[6.1]
  def change
    create_table :addresses do |t|
      t.string :address_line
      t.string :city
      t.string :postal_code
      t.integer :customer_id

      t.timestamps
    end
  end
end
