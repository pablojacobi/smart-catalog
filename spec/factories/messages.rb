# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :conversation
    role { 'user' }
    content { Faker::Lorem.sentence }
    metadata { {} }

    trait :user do
      role { 'user' }
    end

    trait :assistant do
      role { 'assistant' }
      metadata { { 'product_ids' => [] } }
    end

    trait :system do
      role { 'system' }
    end

    trait :with_products do
      role { 'assistant' }
      transient do
        products { create_list(:product, 3) }
      end
      metadata { { 'product_ids' => products.map(&:id) } }
    end
  end
end
