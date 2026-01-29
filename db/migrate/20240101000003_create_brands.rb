# frozen_string_literal: true

class CreateBrands < ActiveRecord::Migration[8.0]
  def change
    create_table :brands, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      t.timestamps
    end

    add_index :brands, :slug, unique: true
    add_index :brands, :name
  end
end
