class AddPhoneAndCurrencyToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :phone, :string
    add_column :customers, :currency, :string
  end
end
