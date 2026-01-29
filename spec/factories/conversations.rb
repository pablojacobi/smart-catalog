# frozen_string_literal: true

FactoryBot.define do
  factory :conversation do
    user { nil }
    metadata { {} }
    title { nil }

    trait :with_user do
      user { association :user }
    end

    trait :with_messages do
      after(:create) do |conversation|
        create(:message, :user, conversation: conversation, content: 'Show me laptops')
        create(:message, :assistant, conversation: conversation, content: 'Here are the laptops...')
      end
    end
  end
end
