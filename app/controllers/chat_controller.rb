# frozen_string_literal: true

# Controller for the chat UI with SSE streaming
class ChatController < ApplicationController
  include ActionController::Live

  before_action :authenticate_user!

  # Skip CSRF for SSE streaming endpoint
  skip_before_action :verify_authenticity_token, only: [:stream]

  def index
    @conversation = current_user.conversations.create!
    @conversations = current_user.conversations.recent.limit(20)
  end

  def show
    @conversation = current_user.conversations.find(params[:id])
    @conversations = current_user.conversations.recent.limit(20)
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

      # Generate title for new conversations
      generate_title(conversation) if conversation.title.blank? && conversation.messages.count == 2

      # Send completion event with metadata
      write_sse_event('done', {
        conversation_id: result[:conversation_id],
        conversation_title: conversation.reload.display_title,
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
      current_user.conversations.find(params[:conversation_id])
    else
      current_user.conversations.create!
    end
  end

  def generate_title(conversation)
    first_message = conversation.first_user_message&.content
    return if first_message.blank?

    client = Gemini::ClientService.new
    prompt = <<~PROMPT.squish
      Generate a very short title (max 5 words) for a conversation that starts with:
      '#{first_message.truncate(100)}'. Return only the title, no quotes or explanation.
    PROMPT

    result = client.generate_content([{ role: 'user', content: prompt }], temperature: 0.3, max_tokens: 20)
    title = result[:content]&.strip&.gsub(/^["']|["']$/, '')
    conversation.update!(title: title) if title.present?
  rescue StandardError => e
    Rails.logger.warn("[ChatController] Failed to generate title: #{e.message}")
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
