# frozen_string_literal: true

module API
  module V1
    class ChatController < BaseController
      # POST /api/v1/chat/completions
      # Main chat endpoint - OpenAI-compatible format
      def completions
        conversation = find_or_create_conversation
        message = extract_message

        result = Chat::OrchestratorService.call(
          conversation: conversation,
          message: message
        )

        render json: format_response(result, conversation)
      rescue SmartCatalog::Error
        # Let ErrorHandler concern handle SmartCatalog errors
        raise
      rescue StandardError => e
        Rails.logger.error("[ChatController] Error: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))

        render json: {
          error: {
            message: e.message,
            code: 'internal_error'
          }
        }, status: :internal_server_error
      end

      private

      def find_or_create_conversation
        if params[:conversation_id].present?
          Conversation.find(params[:conversation_id])
        else
          Conversation.create!
        end
      end

      def extract_message
        # Support both OpenAI format and simple message format
        if params[:messages].is_a?(Array)
          user_message = params[:messages].reverse.find { |m| m[:role] == 'user' || m['role'] == 'user' }
          user_message&.dig(:content) || user_message&.dig('content') || ''
        else
          params[:message] || params[:query] || ''
        end
      end

      def format_response(result, conversation)
        {
          id: "chatcmpl-#{SecureRandom.hex(12)}",
          object: 'chat.completion',
          created: Time.current.to_i,
          conversation_id: conversation.id,
          choices: [
            {
              index: 0,
              message: {
                role: 'assistant',
                content: result[:content]
              },
              finish_reason: 'stop'
            }
          ],
          usage: {
            prompt_tokens: 0,
            completion_tokens: 0,
            total_tokens: 0
          },
          metadata: result[:metadata]
        }
      end
    end
  end
end
