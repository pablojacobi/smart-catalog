# frozen_string_literal: true

class AddEmbeddingToProductsAndDropDocuments < ActiveRecord::Migration[8.1]
  def up
    # Only add embedding column if pgvector extension is available
    if pgvector_available?
      # Add embedding column to products (768 dimensions for nomic-embed-text)
      add_column :products, :embedding, :vector, limit: 768

      # Add index for fast vector similarity search
      add_index :products, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
    else
      Rails.logger.warn('[Migration] pgvector not available - skipping embedding column')
    end

    # Remove document_id from products
    remove_column :products, :document_id if column_exists?(:products, :document_id)

    # Drop documents table
    drop_table :documents if table_exists?(:documents)
  end

  def down
    # Recreate documents table
    create_table :documents, id: :uuid do |t|
      t.string :filename, null: false
      t.string :content_type
      t.integer :file_size
      t.text :content
      t.string :status, default: 'pending'
      t.jsonb :metadata, default: {}
      t.vector :embedding, limit: 768 if pgvector_available?
      t.timestamps
    end

    # Add document_id back to products
    add_reference :products, :document, type: :uuid, foreign_key: true

    # Remove embedding from products if it exists
    if column_exists?(:products, :embedding)
      remove_index :products, :embedding if index_exists?(:products, :embedding)
      remove_column :products, :embedding
    end
  end

  private

  def pgvector_available?
    execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
  rescue StandardError
    false
  end
end
