# frozen_string_literal: true

module Chat
  # Unified streaming service for chat responses
  # Combines context building with LLM streaming for real-time responses
  class StreamingService
    include CallableService

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful product catalog assistant for an electronics store.

      ## Catalog Contents
      This catalog contains: Laptops, Tablets, and Smartphones.
      Laptops have GPUs (graphics cards) like NVIDIA RTX 4050/4060/4070, Apple M3 GPU, or Integrated.
      We do NOT sell standalone components - GPUs, RAM, etc. are specs of the devices.

      ## Language
      IMPORTANT: Always respond in the same language as the user's question.
      If the user writes in Spanish, respond in Spanish.
      If the user writes in English, respond in English.

      ## Your Role
      - Help users find products, compare options, and answer questions
      - Be concise but informative
      - Use ONLY the provided product data - don't make up products
      - When users ask about "graphics card" or "GPU", show laptops with those specs
      - NEVER say "I don't have X in the catalog" if products are provided in the context

      ## Response Formatting Rules
      When listing products, use this EXACT format:

      **Product Name** - Brand
      - Price: $X,XXX
      - Category: Category Name
      - Key specs: CPU, RAM, GPU, etc.

      DO NOT use asterisks (*) for the product name - use **bold** markdown.
      Keep each product clearly separated with a blank line.

      ## Other Guidelines
      - For comparisons: Create a markdown table
      - For counts/statistics: Use the provided statistics
      - For "best GPU/graphics": Show laptops with RTX 4070 > 4060 > 4050 > Integrated
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
