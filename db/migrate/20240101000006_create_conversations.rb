# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations, id: :uuid do |t|
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
