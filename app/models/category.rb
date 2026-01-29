# frozen_string_literal: true

class Category < ApplicationRecord
  has_many :products, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  scope :with_products, -> { joins(:products).distinct }
  scope :ordered, -> { order(:name) }

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
