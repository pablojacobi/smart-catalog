# frozen_string_literal: true

FactoryBot.define do
  factory :brand do
    sequence(:name) { |n| "Brand #{n}" }
    sequence(:slug) { |n| "brand-#{n}" }
    description { Faker::Lorem.paragraph }
  end
end
