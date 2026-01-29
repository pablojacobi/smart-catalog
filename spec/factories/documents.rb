# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    sequence(:filename) { |n| "document_#{n}.pdf" }
    content_type { 'application/pdf' }
    content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    summary { Faker::Lorem.paragraph }
    status { 'completed' }
    content_length { content&.length || 0 }
    processed_at { Time.current }
    metadata { {} }

    trait :pending do
      status { 'pending' }
      content { nil }
      summary { nil }
      processed_at { nil }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :failed do
      status { 'failed' }
      metadata { { 'error' => 'Processing failed' } }
    end

    trait :with_embedding do
      embedding { Array.new(768) { rand(-1.0..1.0) } }
    end

    trait :with_products do
      after(:create) do |document|
        create_list(:product, 3, document: document)
      end
    end
  end
end
