# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:sku) { |n| "SKU-#{n.to_s.rjust(6, '0')}" }
    description { Faker::Lorem.paragraph }
    price { Faker::Commerce.price(range: 10.0..1000.0) }
    currency { 'USD' }
    status { 'active' }
    in_stock { true }
    stock_quantity { rand(1..100) }
    specifications do
      {
        'weight' => "#{rand(0.1..10.0).round(2)} kg",
        'dimensions' => "#{rand(10..50)}x#{rand(10..50)}x#{rand(10..50)} cm",
        'color' => Faker::Color.color_name
      }
    end

    association :category
    association :brand
    association :document

    trait :without_document do
      document { nil }
    end

    trait :out_of_stock do
      in_stock { false }
      stock_quantity { 0 }
    end

    trait :inactive do
      status { 'inactive' }
    end

    trait :expensive do
      price { Faker::Commerce.price(range: 5000.0..50000.0) }
    end

    trait :cheap do
      price { Faker::Commerce.price(range: 1.0..50.0) }
    end
  end
end
