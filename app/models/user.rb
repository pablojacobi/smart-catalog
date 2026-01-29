# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules
  # Note: :registerable is intentionally excluded - users are created via seeds only
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :conversations, dependent: :destroy
end
