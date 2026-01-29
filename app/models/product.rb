# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :category, optional: true
  belongs_to :brand, optional: true

  # pgvector for semantic search
  has_neighbors :embedding

  validates :name, presence: true
  validates :sku, uniqueness: true, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, inclusion: { in: %w[USD EUR GBP] }, allow_nil: true

  # Status states
  STATUSES = %w[active inactive discontinued].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: 'active') }
  scope :in_stock, -> { where(in_stock: true) }
  scope :with_price, -> { where.not(price: nil) }
  scope :with_embedding, -> { where.not(embedding: nil) }
  scope :without_embedding, -> { where(embedding: nil) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :by_brand, ->(brand_id) { where(brand_id: brand_id) }
  scope :price_range, ->(min, max) { where(price: min..max) }
  scope :ordered_by_price, ->(direction = :asc) { order(price: direction) }
  scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") }

  def formatted_price
    return nil unless price

    "#{currency} #{price.to_f.round(2)}"
  end

  def specification(key)
    specifications&.dig(key.to_s)
  end

  # Generate text representation for embedding
  def embedding_text
    parts = [name]
    parts << "by #{brand.name}" if brand
    parts << "in #{category.name}" if category
    parts << description if description.present?

    if specifications.present?
      specs = specifications.map { |k, v| "#{k}: #{v}" }.join(', ')
      parts << specs
    end

    parts.join('. ')
  end
end
