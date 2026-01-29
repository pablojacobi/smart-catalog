# frozen_string_literal: true

class User < ApplicationRecord
  # Include only necessary devise modules
  # Excluded: :registerable (users created via seeds only)
  # Excluded: :recoverable (no password reset emails - no mailer needed)
  devise :database_authenticatable, :rememberable, :validatable

  has_many :conversations, dependent: :destroy
end
