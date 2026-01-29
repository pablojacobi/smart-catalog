# frozen_string_literal: true

class DocumentBlueprint < ApplicationBlueprint
  identifier :id

  fields :filename, :content_type, :status, :content_length

  field :products_count do |document, _options|
    document.products.size
  end

  field :processed_at do |document, _options|
    format_datetime(document.processed_at)
  end

  field :created_at do |document, _options|
    format_datetime(document.created_at)
  end

  view :normal do
    field :summary
  end

  view :extended do
    include_view :normal

    field :metadata

    association :products, blueprint: ProductBlueprint, view: :minimal do |document, _options|
      document.products.limit(20)
    end
  end

  view :with_content do
    include_view :extended

    field :content
  end
end
