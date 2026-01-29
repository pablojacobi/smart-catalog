# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[system user assistant].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :by_role, ->(role) { where(role: role) }
  scope :ordered, -> { order(created_at: :asc) }
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

  def user?
    role == 'user'
  end

  def assistant?
    role == 'assistant'
  end

  def system?
    role == 'system'
  end
end
