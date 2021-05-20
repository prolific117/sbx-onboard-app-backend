class AddActiveToMadateSessionTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :mandate_session_tokens, :active, :boolean
  end
end
