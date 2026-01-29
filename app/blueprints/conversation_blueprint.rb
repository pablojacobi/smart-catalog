# frozen_string_literal: true

class ConversationBlueprint < ApplicationBlueprint
  identifier :id

  field :messages_count do |conversation, _options|
    conversation.messages.count
  end

  field :created_at do |conversation, _options|
    format_datetime(conversation.created_at)
  end

  view :with_messages do
    association :messages, blueprint: MessageBlueprint do |conversation, _options|
      conversation.messages.ordered
    end
  end
end
