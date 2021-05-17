class AddAccessTokenAndOrganisationIdToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :access_token, :string
    add_column :users, :organisation_id, :string
  end
end
