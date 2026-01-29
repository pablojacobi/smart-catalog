# frozen_string_literal: true

# Controller for the chat UI with SSE streaming
class ChatController < ApplicationController
  include ActionController::Live

  # Skip CSRF for SSE streaming endpoint
  skip_before_action :verify_authenticity_token, only: [:stream]

  def index
    @conversation = Conversation.create!
  end

  def show
    @conversation = Conversation.find(params[:id])
  end

  # SSE endpoint for streaming chat responses
  def stream
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # Disable nginx buffering

    conversation = find_or_create_conversation
    message = params[:message]

    return render_error('Message is required') if message.blank?

    streaming_service = Chat::StreamingService.new

    begin
      result = streaming_service.call(conversation: conversation, message: message) do |chunk|
        # Send each chunk as an SSE event
        write_sse_event('chunk', chunk)
      end

      # Send completion event with metadata
      write_sse_event('done', {
        conversation_id: result[:conversation_id],
        product_count: result[:product_ids].length,
        duration_ms: result[:duration_ms]
      }.to_json)
    rescue StandardError => e
      Rails.logger.error("[ChatStream] Error: #{e.message}")
      write_sse_event('error', e.message)
    ensure
      response.stream.close
    end
  end

  private

  def find_or_create_conversation
    if params[:conversation_id].present?
      Conversation.find(params[:conversation_id])
    else
      Conversation.create!
    end
  end

  def write_sse_event(event, data)
    response.stream.write("event: #{event}\n")
    # SSE requires each line of data to be prefixed with 'data: '
    # Multi-line data needs each line prefixed, or we encode newlines
    encoded_data = data.to_s.gsub("\n", '\n').gsub("\r", '\r')
    response.stream.write("data: #{encoded_data}\n\n")
  rescue IOError
    # Client disconnected
    Rails.logger.info('[ChatStream] Client disconnected')
  end

  def render_error(message)
    write_sse_event('error', message)
    response.stream.close
  end
end
