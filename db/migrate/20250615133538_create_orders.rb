class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :total_cents, null: false
      t.string :currency, default: 'CZK', null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
    add_index :orders, :status
    add_index :orders, [:user_id, :created_at]
  end
end
