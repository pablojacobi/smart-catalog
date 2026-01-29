# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents, id: :uuid do |t|
      t.string :filename, null: false
      t.string :content_type
      t.text :content
      t.text :summary
      t.vector :embedding, limit: 768  # Gemini text-embedding-004
      t.string :storage_path
      t.integer :content_length, default: 0
      t.string :status, default: 'pending'
      t.datetime :processed_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :documents, :filename
    add_index :documents, :status
    add_index :documents, :processed_at
  end
end
