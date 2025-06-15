class AddPaymentFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :payment_id, :string
    add_column :orders, :payment_url, :string
    add_column :orders, :payment_status, :integer, default: 0

    # Indexy pro rychlé vyhledávání
    add_index :orders, :payment_id
    add_index :orders, :payment_status
  end
end
