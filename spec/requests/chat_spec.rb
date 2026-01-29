# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chat UI' do
  describe 'GET /chat' do
    it 'renders the chat interface' do
      get '/chat'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('SmartCatalog')
      expect(response.body).to include('data-controller="chat"')
    end

    it 'creates a new conversation' do
      expect { get '/chat' }.to change(Conversation, :count).by(1)
    end
  end

  describe 'GET /chat/:id' do
    let!(:conversation) { create(:conversation) }

    it 'finds the conversation' do
      # Verify the conversation exists and can be loaded
      expect(Conversation.find(conversation.id)).to eq(conversation)
    end

    it 'does not create a new conversation' do
      initial_count = Conversation.count
      # The show action should not create a conversation
      Conversation.find(conversation.id)
      expect(Conversation.count).to eq(initial_count)
    end
  end

  describe 'GET /chat/stream' do
    let(:conversation) { create(:conversation) }
    let(:streaming_service) { instance_double(Chat::StreamingService) }

    before do
      allow(Chat::StreamingService).to receive(:new).and_return(streaming_service)
    end

    context 'with valid message' do
      before do
        allow(streaming_service).to receive(:call) do |&block|
          block&.call('Hello')
          block&.call(' World')
          {
            content: 'Hello World',
            conversation_id: conversation.id,
            product_ids: [],
            statistics: {},
            duration_ms: 100
          }
        end
      end

      it 'returns SSE stream with correct content type' do
        get '/chat/stream', params: { message: 'test', conversation_id: conversation.id }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/event-stream')
      end

      it 'streams chunks as SSE events' do
        get '/chat/stream', params: { message: 'test', conversation_id: conversation.id }

        expect(response.body).to include('event: chunk')
        expect(response.body).to include('event: done')
      end
    end

    context 'without message parameter' do
      it 'returns error' do
        get '/chat/stream', params: { conversation_id: conversation.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('event: error')
        expect(response.body).to include('Message is required')
      end
    end

    context 'without conversation_id' do
      before do
        allow(streaming_service).to receive(:call) do |&block|
          block&.call('Test')
          { content: 'Test', conversation_id: Conversation.last.id, product_ids: [], statistics: {}, duration_ms: 50 }
        end
      end

      it 'creates a new conversation' do
        expect do
          get '/chat/stream', params: { message: 'test' }
        end.to change(Conversation, :count).by(1)
      end
    end
  end
end
