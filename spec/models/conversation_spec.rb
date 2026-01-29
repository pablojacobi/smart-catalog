# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversation do
  describe 'associations' do
    it { is_expected.to have_many(:messages).dependent(:destroy) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders conversations by updated_at descending' do
        old_conv = create(:conversation, updated_at: 2.days.ago)
        new_conv = create(:conversation, updated_at: 1.hour.ago)

        expect(described_class.recent).to eq([new_conv, old_conv])
      end
    end
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

  describe '#first_user_message' do
    it 'returns the first user message' do
      conversation = create(:conversation)
      first_msg = create(:message, :user, conversation: conversation, content: 'First', created_at: 2.hours.ago)
      create(:message, :user, conversation: conversation, content: 'Second', created_at: 1.hour.ago)

      expect(conversation.first_user_message).to eq(first_msg)
    end

    it 'returns nil if no user messages' do
      conversation = create(:conversation)
      create(:message, :assistant, conversation: conversation)

      expect(conversation.first_user_message).to be_nil
    end
  end

  describe '#display_title' do
    it 'returns title if present' do
      conversation = create(:conversation, title: 'Custom Title')
      expect(conversation.display_title).to eq('Custom Title')
    end

    it 'returns truncated first user message if no title' do
      conversation = create(:conversation, title: nil)
      long_message = 'A' * 100
      create(:message, :user, conversation: conversation, content: long_message)

      expect(conversation.display_title.length).to eq(50)
      expect(conversation.display_title).to end_with('...')
    end

    it 'returns default text if no title and no messages' do
      conversation = create(:conversation, title: nil)
      expect(conversation.display_title).to eq('New Conversation')
    end
  end
end
