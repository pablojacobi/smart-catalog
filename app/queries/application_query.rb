# frozen_string_literal: true

# Base class for Query Objects
# Query objects encapsulate complex database queries
#
# Usage:
#   ProductQuery.new.active.by_category('electronics').price_range(100, 500).call
#
class ApplicationQuery
  attr_reader :relation

  def initialize(relation = default_relation)
    @relation = relation
  end

  # Execute the query and return results
  def call
    relation
  end

  # Alias for call
  delegate :to_a, to: :call

  # Count results
  delegate :count, to: :relation

  # Check if any results exist
  delegate :exists?, to: :relation

  private

  # Override in subclasses to set default relation
  def default_relation
    raise NotImplementedError, 'Subclasses must implement #default_relation'
  end

  # Chain a new scope to the relation
  def chain(new_relation)
    self.class.new(new_relation)
  end
end
