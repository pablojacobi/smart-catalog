# frozen_string_literal: true

class Conversation < ApplicationRecord
  belongs_to :user, optional: true
  has_many :messages, dependent: :destroy

  scope :recent, -> { order(updated_at: :desc) }

  def add_message(role:, content:, metadata: {})
    messages.create!(role: role, content: content, metadata: metadata)
  end

  def last_assistant_message
    messages.where(role: 'assistant').order(created_at: :desc).first
  end

  def previous_product_ids
    last_assistant_message&.metadata&.dig('product_ids') || []
  end

  def first_user_message
    messages.where(role: 'user').order(created_at: :asc).first
  end

  def display_title
    title.presence || first_user_message&.content&.truncate(50) || 'New Conversation'
  end
end
