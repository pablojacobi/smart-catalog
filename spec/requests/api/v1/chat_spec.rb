# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Chat' do
  describe 'POST /api/v1/chat/completions' do
    let(:orchestrator_result) do
      {
        content: 'Here are some products matching your search.',
        conversation_id: SecureRandom.uuid,
        metadata: { query_type: 'listing', product_count: 5, duration_ms: 150 }
      }
    end

    before do
      allow(Chat::OrchestratorService).to receive(:call).and_return(orchestrator_result)
    end

    context 'with simple message format' do
      it 'returns chat completion response' do
        post '/api/v1/chat/completions', params: { message: 'Show me laptops' }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['object']).to eq('chat.completion')
        expect(json['choices']).to be_an(Array)
        expect(json['choices'].first['message']['role']).to eq('assistant')
        expect(json['choices'].first['message']['content']).to eq('Here are some products matching your search.')
      end

      it 'includes conversation_id for follow-up' do
        post '/api/v1/chat/completions', params: { message: 'Show me laptops' }

        json = response.parsed_body

        expect(json['conversation_id']).to be_present
      end

      it 'includes metadata' do
        post '/api/v1/chat/completions', params: { message: 'Show me laptops' }

        json = response.parsed_body

        expect(json['metadata']['query_type']).to eq('listing')
        expect(json['metadata']['product_count']).to eq(5)
      end
    end

    context 'with OpenAI-compatible format' do
      it 'extracts message from messages array' do
        post '/api/v1/chat/completions', params: {
          messages: [
            { role: 'user', content: 'Show me phones under $500' }
          ]
        }

        expect(response).to have_http_status(:ok)
        expect(Chat::OrchestratorService).to have_received(:call).with(
          hash_including(message: 'Show me phones under $500')
        )
      end

      it 'uses latest user message' do
        post '/api/v1/chat/completions', params: {
          messages: [
            { role: 'user', content: 'Show me laptops' },
            { role: 'assistant', content: 'Here are some laptops...' },
            { role: 'user', content: 'Which is the cheapest?' }
          ]
        }

        expect(Chat::OrchestratorService).to have_received(:call).with(
          hash_including(message: 'Which is the cheapest?')
        )
      end
    end

    context 'with existing conversation' do
      let!(:conversation) { create(:conversation) }

      it 'continues the conversation' do
        post '/api/v1/chat/completions', params: {
          conversation_id: conversation.id,
          message: 'From those, which are in stock?'
        }

        expect(response).to have_http_status(:ok)
        expect(Chat::OrchestratorService).to have_received(:call).with(
          hash_including(conversation: conversation)
        )
      end
    end

    context 'when service raises SmartCatalog error' do
      before do
        allow(Chat::OrchestratorService).to receive(:call)
          .and_raise(SmartCatalog::GeminiError.new('API quota exceeded'))
      end

      it 'returns error response with specific error code' do
        post '/api/v1/chat/completions', params: { message: 'Test' }

        expect(response).to have_http_status(:internal_server_error)
        json = response.parsed_body

        expect(json['error']['message']).to eq('API quota exceeded')
        expect(json['error']['code']).to eq('gemini_error')
      end
    end

    context 'when service raises unexpected StandardError' do
      before do
        allow(Chat::OrchestratorService).to receive(:call)
          .and_raise(StandardError.new('Something unexpected happened'))
      end

      it 'returns internal error response' do
        post '/api/v1/chat/completions', params: { message: 'Test' }

        expect(response).to have_http_status(:internal_server_error)
        json = response.parsed_body

        expect(json['error']['message']).to eq('Something unexpected happened')
        expect(json['error']['code']).to eq('internal_error')
      end
    end
  end
end
