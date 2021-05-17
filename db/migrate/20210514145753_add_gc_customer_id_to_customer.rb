class AddGcCustomerIdToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :gocardless_customer_id, :string
  end
end
