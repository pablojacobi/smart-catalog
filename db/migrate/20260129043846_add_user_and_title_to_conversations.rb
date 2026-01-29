class AddUserAndTitleToConversations < ActiveRecord::Migration[8.1]
  def change
    add_reference :conversations, :user, null: true, foreign_key: true, type: :uuid
    add_column :conversations, :title, :string
  end
end
