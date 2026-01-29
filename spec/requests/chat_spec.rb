# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chat UI' do
  let(:user) { create(:user) }

  describe 'GET /chat' do
    context 'when authenticated' do
      before { sign_in user }

      it 'renders the chat interface' do
        get '/chat'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('SmartCatalog')
        expect(response.body).to include('data-controller="chat"')
      end

      it 'creates a new conversation for the user' do
        expect { get '/chat' }.to change(Conversation, :count).by(1)
        expect(Conversation.last.user).to eq(user)
      end
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        get '/chat'

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /chat/:id' do
    let!(:conversation) { create(:conversation, user: user) }

    before { sign_in user }

    it 'renders the conversation' do
      get chat_conversation_path(conversation)

      expect(response).to have_http_status(:ok)
    end

    it 'does not allow access to other users conversations' do
      other_user = create(:user)
      other_conversation = create(:conversation, user: other_user)

      # RecordNotFound is rescued and returns 404 in Rails
      get chat_conversation_path(other_conversation)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /chat/stream' do
    let!(:conversation) { create(:conversation, user: user) }
    let(:streaming_service) { instance_double(Chat::StreamingService) }

    before do
      sign_in user
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

      it 'creates a new conversation for the user' do
        expect do
          get '/chat/stream', params: { message: 'test' }
        end.to change(Conversation, :count).by(1)
        expect(Conversation.last.user).to eq(user)
      end
    end

    context 'when streaming service raises an error' do
      before do
        allow(streaming_service).to receive(:call).and_raise(StandardError.new('API Error'))
      end

      it 'streams error event' do
        get '/chat/stream', params: { message: 'test', conversation_id: conversation.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('event: error')
        expect(response.body).to include('API Error')
      end
    end

    context 'with title generation' do
      let(:gemini_client) { instance_double(Gemini::ClientService) }

      before do
        # Create a conversation with exactly 2 messages after streaming
        conversation.update!(title: nil)
        conversation.add_message(role: 'user', content: 'Hello')

        allow(streaming_service).to receive(:call) do |&block|
          conversation.add_message(role: 'assistant', content: 'Hi there')
          block&.call('Hi there')
          { content: 'Hi there', conversation_id: conversation.id, product_ids: [], statistics: {}, duration_ms: 50 }
        end

        allow(Gemini::ClientService).to receive(:new).and_return(gemini_client)
        allow(gemini_client).to receive(:generate_content).and_return({ content: 'Greeting conversation' })
      end

      it 'generates title for new conversation' do
        get '/chat/stream', params: { message: 'Hello', conversation_id: conversation.id }

        expect(gemini_client).to have_received(:generate_content)
        expect(conversation.reload.title).to eq('Greeting conversation')
      end
    end

    context 'when title generation fails' do
      let(:gemini_client) { instance_double(Gemini::ClientService) }

      before do
        conversation.update!(title: nil)
        conversation.add_message(role: 'user', content: 'Hello')

        allow(streaming_service).to receive(:call) do |&block|
          conversation.add_message(role: 'assistant', content: 'Response')
          block&.call('Response')
          { content: 'Response', conversation_id: conversation.id, product_ids: [], statistics: {}, duration_ms: 50 }
        end

        allow(Gemini::ClientService).to receive(:new).and_return(gemini_client)
        allow(gemini_client).to receive(:generate_content).and_raise(StandardError.new('API Error'))
      end

      it 'logs warning but does not fail the request' do
        allow(Rails.logger).to receive(:warn)

        get '/chat/stream', params: { message: 'Hello', conversation_id: conversation.id }

        expect(Rails.logger).to have_received(:warn).with(/Failed to generate title/)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('event: done')
      end
    end

    context 'when title generation returns empty' do
      let(:gemini_client) { instance_double(Gemini::ClientService) }

      before do
        conversation.update!(title: nil)
        conversation.add_message(role: 'user', content: 'Hello')

        allow(streaming_service).to receive(:call) do |&block|
          conversation.add_message(role: 'assistant', content: 'Response')
          block&.call('Response')
          { content: 'Response', conversation_id: conversation.id, product_ids: [], statistics: {}, duration_ms: 50 }
        end

        allow(Gemini::ClientService).to receive(:new).and_return(gemini_client)
        allow(gemini_client).to receive(:generate_content).and_return({ content: '' })
      end

      it 'does not update title with empty string' do
        get '/chat/stream', params: { message: 'Hello', conversation_id: conversation.id }

        expect(conversation.reload.title).to be_nil
      end
    end

    context 'when conversation already has title' do
      let(:gemini_client) { instance_double(Gemini::ClientService) }

      before do
        conversation.update!(title: 'Existing Title')
        conversation.add_message(role: 'user', content: 'Hello')

        allow(streaming_service).to receive(:call) do |&block|
          conversation.add_message(role: 'assistant', content: 'Response')
          block&.call('Response')
          { content: 'Response', conversation_id: conversation.id, product_ids: [], statistics: {}, duration_ms: 50 }
        end

        allow(Gemini::ClientService).to receive(:new).and_return(gemini_client)
        allow(gemini_client).to receive(:generate_content)
      end

      it 'does not regenerate title' do
        get '/chat/stream', params: { message: 'Another message', conversation_id: conversation.id }

        expect(gemini_client).not_to have_received(:generate_content)
        expect(conversation.reload.title).to eq('Existing Title')
      end
    end
  end
end
