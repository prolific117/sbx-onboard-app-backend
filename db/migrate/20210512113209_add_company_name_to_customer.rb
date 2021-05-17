class AddCompanyNameToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :company_name, :string
  end
end
