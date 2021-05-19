class AddPaymentIdToPayment < ActiveRecord::Migration[6.1]
  def change
    add_column :payments, :payment_id, :string
  end
end
