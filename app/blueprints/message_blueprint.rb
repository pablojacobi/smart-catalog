# frozen_string_literal: true

class MessageBlueprint < ApplicationBlueprint
  identifier :id

  fields :role, :content

  field :created_at do |message, _options|
    format_datetime(message.created_at)
  end

  view :extended do
    field :metadata
    field :conversation_id
  end
end
