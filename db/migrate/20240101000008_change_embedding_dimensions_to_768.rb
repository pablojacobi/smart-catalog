# frozen_string_literal: true

class ChangeEmbeddingDimensionsTo768 < ActiveRecord::Migration[8.1]
  def up
    # Change embedding column from 1536 (OpenAI) to 768 (Gemini) dimensions
    change_column :documents, :embedding, :vector, limit: 768
  end

  def down
    change_column :documents, :embedding, :vector, limit: 1536
  end
end
