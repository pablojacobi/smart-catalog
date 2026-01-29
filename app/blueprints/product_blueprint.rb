# frozen_string_literal: true

class ProductBlueprint < ApplicationBlueprint
  identifier :id

  fields :name, :sku, :price, :currency, :in_stock

  field :formatted_price do |product, _options|
    product.formatted_price
  end

  association :category, blueprint: CategoryBlueprint
  association :brand, blueprint: BrandBlueprint

  view :normal do
    fields :description, :status, :stock_quantity
  end

  view :extended do
    include_view :normal

    field :specifications
    field :document_id

    field :created_at do |product, _options|
      format_datetime(product.created_at)
    end

    field :updated_at do |product, _options|
      format_datetime(product.updated_at)
    end
  end

  # Minimal view for lists and search results
  view :minimal do
    excludes :category, :brand
    field :category_name do |product, _options|
      product.category&.name
    end
    field :brand_name do |product, _options|
      product.brand&.name
    end
  end
end
