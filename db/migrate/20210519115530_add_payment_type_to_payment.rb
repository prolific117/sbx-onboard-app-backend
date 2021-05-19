class AddPaymentTypeToPayment < ActiveRecord::Migration[6.1]
  def change
    add_column :payments, :payment_type, :string
  end
end
