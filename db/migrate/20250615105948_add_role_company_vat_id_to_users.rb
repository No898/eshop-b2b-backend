class AddRoleCompanyVatIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :integer
    add_column :users, :company_name, :string
    add_column :users, :vat_id, :string
  end
end
