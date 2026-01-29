# frozen_string_literal: true

class CategoryBlueprint < ApplicationBlueprint
  identifier :id

  fields :name, :slug

  view :normal do
    field :description
    field :products_count do |category, _options|
      category.products.count
    end
  end

  view :extended do
    include_view :normal

    field :created_at do |category, _options|
      format_datetime(category.created_at)
    end

    field :updated_at do |category, _options|
      format_datetime(category.updated_at)
    end
  end
end
