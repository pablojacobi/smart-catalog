# frozen_string_literal: true

class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  def add_message(role:, content:, metadata: {})
    messages.create!(role: role, content: content, metadata: metadata)
  end

  def last_assistant_message
    messages.where(role: 'assistant').order(created_at: :desc).first
  end

  def previous_product_ids
    last_assistant_message&.metadata&.dig('product_ids') || []
  end
end
