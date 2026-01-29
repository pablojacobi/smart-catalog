# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversation do
  describe 'associations' do
    it { is_expected.to have_many(:messages).dependent(:destroy) }
  end

  describe '#add_message' do
    it 'creates a new message with given attributes' do
      conversation = create(:conversation)

      message = conversation.add_message(
        role: 'user',
        content: 'Hello',
        metadata: { test: true }
      )

      expect(message).to be_persisted
      expect(message.role).to eq('user')
      expect(message.content).to eq('Hello')
      expect(message.metadata).to eq({ 'test' => true })
    end
  end

  describe '#last_assistant_message' do
    it 'returns the most recent assistant message' do
      conversation = create(:conversation)
      create(:message, :assistant, conversation: conversation, content: 'First', created_at: 1.hour.ago)
      last_msg = create(:message, :assistant, conversation: conversation, content: 'Last')
      create(:message, :user, conversation: conversation, content: 'User message')

      expect(conversation.last_assistant_message).to eq(last_msg)
    end

    it 'returns nil if no assistant messages' do
      conversation = create(:conversation)
      create(:message, :user, conversation: conversation)

      expect(conversation.last_assistant_message).to be_nil
    end
  end

  describe '#previous_product_ids' do
    it 'returns product IDs from last assistant message' do
      conversation = create(:conversation)
      products = create_list(:product, 3)
      create(:message, :assistant, conversation: conversation, metadata: { 'product_ids' => products.map(&:id) })

      expect(conversation.previous_product_ids).to eq(products.map(&:id))
    end

    it 'returns empty array if no previous messages' do
      conversation = create(:conversation)
      expect(conversation.previous_product_ids).to eq([])
    end
  end
end
