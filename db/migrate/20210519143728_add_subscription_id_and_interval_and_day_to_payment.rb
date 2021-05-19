class AddSubscriptionIdAndIntervalAndDayToPayment < ActiveRecord::Migration[6.1]
  def change
    add_column :payments, :subscription_id, :string
    add_column :payments, :interval, :string
    add_column :payments, :day_of_month, :integer
  end
end
