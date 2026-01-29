# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationBlueprint do
  let(:conversation) { create(:conversation) }

  describe 'default view' do
    subject(:result) { described_class.render_as_hash(conversation) }

    it 'includes id' do
      expect(result[:id]).to eq(conversation.id)
    end

    it 'includes messages_count' do
      create_list(:message, 5, conversation: conversation)
      result = described_class.render_as_hash(conversation)

      expect(result[:messages_count]).to eq(5)
    end

    it 'includes formatted created_at' do
      expect(result[:created_at]).to be_present
    end
  end

  describe 'with_messages view' do
    subject(:result) { described_class.render_as_hash(conversation, view: :with_messages) }

    before do
      create(:message, conversation: conversation, role: 'user', content: 'Hello')
      create(:message, conversation: conversation, role: 'assistant', content: 'Hi there!')
    end

    it 'includes messages association' do
      expect(result[:messages]).to be_an(Array)
      expect(result[:messages].length).to eq(2)
    end

    it 'includes message details' do
      expect(result[:messages].first[:role]).to eq('user')
      expect(result[:messages].first[:content]).to eq('Hello')
    end

    it 'orders messages' do
      # Messages should be in chronological order
      roles = result[:messages].pluck(:role)
      expect(roles).to eq(%w[user assistant])
    end
  end

  describe 'collection rendering' do
    let(:conversations) { create_list(:conversation, 3) }

    it 'renders array of conversations' do
      result = described_class.render_as_hash(conversations)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end
  end
end
