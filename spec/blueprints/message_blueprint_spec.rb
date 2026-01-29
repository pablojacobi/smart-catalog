# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageBlueprint do
  let(:conversation) { create(:conversation) }
  let(:message) do
    create(:message,
           conversation: conversation,
           role: 'assistant',
           content: 'Here are some products',
           metadata: { product_ids: [1, 2, 3] })
  end

  describe 'default view' do
    subject(:result) { described_class.render_as_hash(message) }

    it 'includes basic fields' do
      expect(result[:id]).to eq(message.id)
      expect(result[:role]).to eq('assistant')
      expect(result[:content]).to eq('Here are some products')
    end

    it 'includes formatted created_at' do
      expect(result[:created_at]).to be_present
    end
  end

  describe 'extended view' do
    subject(:result) { described_class.render_as_hash(message, view: :extended) }

    it 'includes metadata' do
      expect(result[:metadata]).to eq({ 'product_ids' => [1, 2, 3] })
    end

    it 'includes conversation_id' do
      expect(result[:conversation_id]).to eq(conversation.id)
    end
  end

  describe 'collection rendering' do
    before do
      create(:message, conversation: conversation, role: 'user', content: 'Hello')
      create(:message, conversation: conversation, role: 'assistant', content: 'Hi!')
    end

    it 'renders array of messages' do
      messages = conversation.messages
      result = described_class.render_as_hash(messages)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end
  end
end
