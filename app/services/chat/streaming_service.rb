# frozen_string_literal: true

module Chat
  # Unified streaming service for chat responses
  # Combines context building with LLM streaming for real-time responses
  class StreamingService
    include CallableService

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful product catalog assistant for an electronics store.

      ## Language
      IMPORTANT: Always respond in the same language as the user's question.
      If the user writes in Spanish, respond in Spanish.
      If the user writes in English, respond in English.
      Match the user's language exactly.

      ## Your Role
      - Help users find products, compare options, and answer questions about the catalog
      - Be concise but informative
      - Use the provided product data to give accurate responses
      - If asked about products not in the provided context, say so

      ## Response Formatting Rules
      When listing products, use this EXACT format for each product:

      **Product Name** - Brand
      - Price: $X,XXX
      - Category: Category Name
      - Key specs: CPU, RAM, GPU, etc.

      Example:
      **MacBook Pro 14** - Apple
      - Price: $1,999
      - Category: Laptops
      - Key specs: M3 Pro, 18GB RAM, 512GB SSD

      DO NOT use asterisks (*) for the product name - use **bold** markdown.
      DO NOT mix product info and specs on the same bullet point.
      Keep each product clearly separated with a blank line.

      ## Other Guidelines
      - For comparisons: Create clear side-by-side analysis with a table or structured comparison
      - For counts/statistics: Use the provided statistics, don't make up numbers
      - For general questions: Be helpful and suggest relevant products
      - Always mention if a product is out of stock
    PROMPT

    def initialize(gemini_client: nil, context_builder: nil, classifier: nil)
      @gemini_client = gemini_client || Gemini::ClientService.new
      @context_builder = context_builder || ContextBuilderService.new
      @classifier = classifier || QueryClassifierService.new
    end

    # Stream a chat response
    # @param conversation [Conversation] The conversation context
    # @param message [String] User's message
    # @yield [String] Yields each text chunk as it arrives
    # @return [Hash] Final response metadata
    def call(conversation:, message:, &block)
      Rails.logger.info("[StreamingService] Processing: '#{message.truncate(80)}'")
      start_time = Time.current

      # Store user message
      conversation.add_message(role: 'user', content: message)

      # Classify the query to extract filters
      classification = @classifier.call(message, context: build_conversation_context(conversation))

      # Build context with statistics and relevant products
      context = @context_builder.call(
        query: classification[:search_query] || message,
        filters: classification[:filters] || {}
      )

      # Build messages for LLM
      messages = build_messages(message, context[:markdown], conversation)

      # Stream response
      full_response = +''
      @gemini_client.stream_content(messages, temperature: 0.7) do |chunk|
        full_response << chunk
        yield chunk if block_given?
      end

      # Store assistant message
      product_ids = context[:products].map(&:id)
      conversation.add_message(
        role: 'assistant',
        content: full_response,
        metadata: { product_ids: product_ids }
      )

      duration = Time.current - start_time
      Rails.logger.info("[StreamingService] Completed in #{duration.round(2)}s")

      {
        content: full_response,
        conversation_id: conversation.id,
        product_ids: product_ids,
        statistics: context[:statistics],
        duration_ms: (duration * 1000).round
      }
    end

    # Non-streaming version for API compatibility
    def call_sync(conversation:, message:)
      response_content = +''
      result = call(conversation: conversation, message: message) do |chunk|
        response_content << chunk
      end
      result.merge(content: response_content)
    end

    private

    def build_conversation_context(conversation)
      previous_products = []
      if conversation.previous_product_ids.any?
        previous_products = Product.where(id: conversation.previous_product_ids).to_a
      end

      { previous_products: previous_products }
    end

    def build_messages(user_message, context_markdown, conversation)
      messages = [
        { role: 'user', content: SYSTEM_PROMPT },
        { role: 'assistant', content: 'Understood. I will help users find products using the provided catalog data.' }
      ]

      # Add conversation history (last 6 messages for context)
      conversation.messages.order(created_at: :desc).limit(6).reverse_each do |msg|
        next if msg.content.blank?

        messages << { role: msg.role, content: msg.content.truncate(1000) }
      end

      # Add current context and user message
      messages << {
        role: 'user',
        content: "## Current Catalog Context\n\n#{context_markdown}\n\n## User Question\n#{user_message}"
      }

      messages
    end
  end
end
