# frozen_string_literal: true

class Document < ApplicationRecord
  has_neighbors :embedding
  has_many :products, dependent: :destroy

  validates :filename, presence: true

  # Status states
  STATUSES = %w[pending processing completed failed].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :with_embedding, -> { where.not(embedding: nil) }
  scope :without_embedding, -> { where(embedding: nil) }

  def processed?
    status == 'completed'
  end

  def processing!
    update!(status: 'processing')
  end

  def complete!
    update!(status: 'completed', processed_at: Time.current)
  end

  def fail!(error_message = nil)
    update!(
      status: 'failed',
      metadata: metadata.merge('error' => error_message)
    )
  end
end
