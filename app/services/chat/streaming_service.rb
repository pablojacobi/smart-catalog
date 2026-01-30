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

      ## Follow-up Questions
      When the context says "Products from previous response", the user is asking about
      THOSE SPECIFIC products only. Answer based on that list, don't search for new products.
      Example: "which has the best GPU?" → compare GPUs of the products shown, not all products.

      ## Other Guidelines
      - For comparisons: Create a markdown table
      - For counts/statistics: Use the provided statistics
      - GPU ranking: RTX 4070 > RTX 4060 > RTX 4050 > Apple M3 GPU > Integrated
      - Always mention if a product is out of stock
    PROMPT

    def initialize(ai_client: nil, gemini_client: nil, context_builder: nil, classifier: nil)
      @ai_client = ai_client || gemini_client || Gemini::ClientService.new
      @context_builder = context_builder || ContextBuilderService.new
      @classifier = classifier || QueryClassifierService.new
    end

    # Stream a chat response
    # @param conversation [Conversation] The conversation context
    # @param message [String] User's message
    # @yield [String] Yields each text chunk as it arrives
    # @return [Hash] Final response metadata
    def call(conversation:, message:, &)
      Rails.logger.info("[StreamingService] Processing: '#{message.truncate(80)}'")
      start_time = Time.current

      conversation.add_message(role: 'user', content: message)
      context = determine_context(conversation, message)
      messages = build_messages(message, context[:markdown], conversation)

      full_response = stream_response(messages, &)
      product_ids = context[:products].map(&:id)

      store_assistant_response(conversation, full_response, product_ids)
      build_result(full_response, conversation, product_ids, context[:statistics], start_time)
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

    def determine_context(conversation, message)
      conv_context = build_conversation_context(conversation)
      classification = @classifier.call(message, context: conv_context)

      if classification[:query_type] == 'contextual' && conv_context[:previous_products].any?
        build_contextual_response(conv_context[:previous_products], message)
      else
        @context_builder.call(
          query: classification[:search_query] || message,
          filters: classification[:filters] || {}
        )
      end
    end

    def stream_response(messages, &)
      full_response = +''
      @ai_client.stream_content(messages, temperature: 0.7) do |chunk|
        full_response << chunk
        yield chunk if block_given?
      end
      full_response
    end

    def store_assistant_response(conversation, content, product_ids)
      conversation.add_message(
        role: 'assistant',
        content: content,
        metadata: { product_ids: product_ids }
      )
    end

    def build_result(content, conversation, product_ids, statistics, start_time)
      duration = Time.current - start_time
      Rails.logger.info("[StreamingService] Completed in #{duration.round(2)}s")

      {
        content: content,
        conversation_id: conversation.id,
        product_ids: product_ids,
        statistics: statistics,
        duration_ms: (duration * 1000).round
      }
    end

    def build_conversation_context(conversation)
      previous_products = []
      if conversation.previous_product_ids.any?
        previous_products = Product.where(id: conversation.previous_product_ids)
          .includes(:brand, :category).to_a
      end

      { previous_products: previous_products }
    end

    def build_contextual_response(previous_products, _message)
      # Format previous products as context for follow-up questions
      markdown = "## Products from previous response (#{previous_products.size})\n"
      markdown << "The user is asking about THESE SPECIFIC products:\n\n"

      previous_products.each_with_index do |product, index|
        stock_indicator = product.in_stock ? '✓ In Stock' : '✗ Out of Stock'
        price_str = product.price ? "$#{product.price}" : 'N/A'

        markdown << "#{index + 1}. **#{product.name}** | #{product.brand&.name || 'N/A'}\n"
        markdown << "   - Category: #{product.category&.name || 'N/A'}\n"
        markdown << "   - Price: #{price_str}\n"
        markdown << "   - Stock: #{stock_indicator}\n"

        if product.specifications.present?
          specs = product.specifications.map { |k, v| "#{k}: #{v}" }.join(', ')
          markdown << "   - Specs: #{specs}\n"
        end
        markdown << "\n"
      end

      {
        statistics: { total: previous_products.size },
        products: previous_products,
        markdown: markdown
      }
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
