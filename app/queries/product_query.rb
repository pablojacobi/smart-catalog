# frozen_string_literal: true

# Query object for complex Product queries
#
# Usage:
#   ProductQuery.new
#     .active
#     .by_category('electronics')
#     .by_brand('apple')
#     .price_range(500, 1500)
#     .in_stock
#     .search('MacBook')
#     .sorted_by(:price, :desc)
#     .call
#
class ProductQuery < ApplicationQuery
  VALID_SORT_FIELDS = %w[name price created_at updated_at].freeze
  VALID_SORT_DIRECTIONS = %w[asc desc].freeze

  # Filter by active status
  def active
    chain(relation.where(status: 'active'))
  end

  # Filter by status
  def by_status(status)
    return self if status.blank?

    chain(relation.where(status: status))
  end

  # Filter by category (slug or ID)
  def by_category(category)
    return self if category.blank?

    category_record = find_category(category)
    return chain(relation.none) unless category_record

    chain(relation.where(category_id: category_record.id))
  end

  # Filter by brand (slug or ID)
  def by_brand(brand)
    return self if brand.blank?

    brand_record = find_brand(brand)
    return chain(relation.none) unless brand_record

    chain(relation.where(brand_id: brand_record.id))
  end

  # Filter by price range
  def price_range(min_price, max_price)
    scope = relation
    scope = scope.where('price >= ?', min_price) if min_price.present?
    scope = scope.where('price <= ?', max_price) if max_price.present?
    chain(scope)
  end

  # Filter by in-stock status
  def in_stock(value = true)
    return self if value.nil?

    chain(relation.where(in_stock: value))
  end

  # Text search on name and description
  def search(query)
    return self if query.blank?

    sanitized = "%#{sanitize_like(query)}%"
    chain(relation.where('name ILIKE ? OR description ILIKE ?', sanitized, sanitized))
  end

  # Filter by specification key-value
  def with_specification(key, value)
    return self if key.blank? || value.blank?

    chain(relation.where('specifications @> ?', { key => value }.to_json))
  end

  # Sort results
  def sorted_by(field, direction = :asc)
    field = field.to_s
    direction = direction.to_s.downcase

    # Validate to prevent SQL injection
    field = 'name' unless VALID_SORT_FIELDS.include?(field)
    direction = 'asc' unless VALID_SORT_DIRECTIONS.include?(direction)

    chain(relation.order("#{field} #{direction}"))
  end

  # Include associations for eager loading
  def with_associations
    chain(relation.includes(:category, :brand))
  end

  # Paginate results
  def paginate(page: 1, per_page: 25)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min

    chain(relation.offset((page - 1) * per_page).limit(per_page))
  end

  private

  def default_relation
    Product.all
  end

  def find_category(category)
    return Category.find_by(id: category) if uuid?(category)

    Category.find_by('slug = ? OR LOWER(name) = ?', category.to_s, category.to_s.downcase)
  end

  def find_brand(brand)
    return Brand.find_by(id: brand) if uuid?(brand)

    Brand.find_by('slug = ? OR LOWER(name) = ?', brand.to_s, brand.to_s.downcase)
  end

  def uuid?(string)
    string.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end

  def sanitize_like(string)
    string.to_s.gsub(/[%_]/) { |m| "\\#{m}" }
  end
end
