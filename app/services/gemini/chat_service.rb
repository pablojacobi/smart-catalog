# frozen_string_literal: true

module Gemini
  # Service for chat completions using Gemini
  class ChatService
    include CallableService

    def initialize(messages:, system_prompt: nil, temperature: 0.7, max_tokens: 2048)
      @messages = messages
      @system_prompt = system_prompt
      @temperature = temperature
      @max_tokens = max_tokens
      @client = ClientService.new
    end

    def call
      formatted_messages = build_messages

      result = @client.generate_content(
        formatted_messages,
        temperature: @temperature,
        max_tokens: @max_tokens
      )

      result[:content]
    end

    private

    def build_messages
      messages = []

      # Gemini handles system prompts as the first user message
      if @system_prompt.present?
        messages << { role: 'user', content: @system_prompt }
        messages << { role: 'assistant', content: 'Understood. I will follow these instructions.' }
      end

      @messages.each do |msg|
        messages << { role: msg[:role], content: msg[:content] }
      end

      messages
    end
  end
end
