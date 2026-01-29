# frozen_string_literal: true

class BrandBlueprint < ApplicationBlueprint
  identifier :id

  fields :name, :slug

  view :normal do
    field :description
    field :products_count do |brand, _options|
      brand.products.count
    end
  end

  view :extended do
    include_view :normal

    field :created_at do |brand, _options|
      format_datetime(brand.created_at)
    end

    field :updated_at do |brand, _options|
      format_datetime(brand.updated_at)
    end
  end
end
