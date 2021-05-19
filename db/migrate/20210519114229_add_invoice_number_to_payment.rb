class AddInvoiceNumberToPayment < ActiveRecord::Migration[6.1]
  def change
    add_column :payments, :invoice_number, :string
  end
end
