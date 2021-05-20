class CreateMandateSessionTokens < ActiveRecord::Migration[6.1]
  def change
    create_table :mandate_session_tokens do |t|
      t.string :mandate_session_token
      t.integer :customer_id

      t.timestamps
    end
  end
end
