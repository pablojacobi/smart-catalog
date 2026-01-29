# frozen_string_literal: true

# Query object for Document queries
#
# Usage:
#   DocumentQuery.new
#     .completed
#     .with_embedding
#     .recent
#     .call
#
class DocumentQuery < ApplicationQuery
  # Filter by status
  def by_status(status)
    return self if status.blank?

    chain(relation.where(status: status))
  end

  # Pending documents
  def pending
    chain(relation.where(status: 'pending'))
  end

  # Processing documents
  def processing
    chain(relation.where(status: 'processing'))
  end

  # Completed documents
  def completed
    chain(relation.where(status: 'completed'))
  end

  # Failed documents
  def failed
    chain(relation.where(status: 'failed'))
  end

  # Documents with embeddings
  def with_embedding
    chain(relation.where.not(embedding: nil))
  end

  # Documents without embeddings
  def without_embedding
    chain(relation.where(embedding: nil))
  end

  # Documents with products
  def with_products
    chain(relation.joins(:products).distinct)
  end

  # Search by filename
  def search(query)
    return self if query.blank?

    chain(relation.where('filename ILIKE ?', "%#{query}%"))
  end

  # Recent documents first
  def recent
    chain(relation.order(created_at: :desc))
  end

  # Include products association
  def with_associations
    chain(relation.includes(:products))
  end

  # Paginate results
  def paginate(page: 1, per_page: 25)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min

    chain(relation.offset((page - 1) * per_page).limit(per_page))
  end

  private

  def default_relation
    Document.all
  end
end
