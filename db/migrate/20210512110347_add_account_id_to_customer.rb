class AddAccountIdToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :account_id, :int
  end
end
