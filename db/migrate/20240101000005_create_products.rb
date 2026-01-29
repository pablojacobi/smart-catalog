# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: :uuid do |t|
      t.references :document, type: :uuid, foreign_key: true
      t.references :category, type: :uuid, foreign_key: true
      t.references :brand, type: :uuid, foreign_key: true

      t.string :name, null: false
      t.string :sku
      t.text :description
      t.decimal :price, precision: 12, scale: 2
      t.string :currency, default: 'USD'
      t.jsonb :specifications, default: {}
      t.string :status, default: 'active'
      t.boolean :in_stock, default: true
      t.integer :stock_quantity

      t.timestamps
    end

    add_index :products, :name
    add_index :products, :sku, unique: true, where: 'sku IS NOT NULL'
    add_index :products, :price
    add_index :products, :status
    add_index :products, :in_stock
    add_index :products, :specifications, using: :gin
  end
end
