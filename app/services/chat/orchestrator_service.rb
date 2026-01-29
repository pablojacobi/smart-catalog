# frozen_string_literal: true

module Chat
  # Main orchestrator service for handling chat requests
  # Coordinates classification, search, and response building
  class OrchestratorService
    include CallableService

    def initialize(
      classifier: nil,
      search_service: nil,
      sql_service: nil,
      response_builder: nil
    )
      @classifier = classifier || QueryClassifierService.new
      @search_service = search_service || Search::HybridSearchService.new
      @sql_service = sql_service || Search::SqlSearchService.new
      @response_builder = response_builder || ResponseBuilderService.new
    end

    # Process a chat message and return response
    #
    # @param conversation [Conversation] The conversation context
    # @param message [String] User's message
    # @return [Hash] Response with content and metadata
    def call(conversation:, message:)
      Rails.logger.info("[ChatOrchestrator] Processing: '#{message.truncate(80)}'")
      start_time = Time.current

      # Store user message
      conversation.add_message(role: 'user', content: message)

      # Get context from previous messages
      context = build_context(conversation)

      # Classify the query
      classification = @classifier.call(message, context: context)

      # Execute appropriate strategy based on query type
      result = execute_strategy(classification, context)

      # Build response
      response = @response_builder.call(
        query_type: classification[:query_type],
        products: result[:products],
        query: message,
        context: result[:context]
      )

      # Store assistant message
      conversation.add_message(
        role: 'assistant',
        content: response[:content],
        metadata: { product_ids: response[:product_ids], response_type: response[:response_type] }
      )

      duration = Time.current - start_time
      Rails.logger.info("[ChatOrchestrator] Completed in #{duration.round(2)}s")

      {
        content: response[:content],
        conversation_id: conversation.id,
        metadata: {
          query_type: classification[:query_type],
          product_count: response[:product_ids].length,
          duration_ms: (duration * 1000).round
        }
      }
    end

    private

    def build_context(conversation)
      previous_products = []
      if conversation.previous_product_ids.any?
        previous_products = Product.where(id: conversation.previous_product_ids).to_a
      end

      { previous_products: previous_products }
    end

    def execute_strategy(classification, context)
      case classification[:query_type]
      when 'count'
        execute_count_strategy(classification[:filters])
      when 'contextual'
        execute_contextual_strategy(classification, context)
      when 'conversational'
        { products: [], context: {} }
      else
        execute_search_strategy(classification)
      end
    end

    def execute_count_strategy(filters)
      counts = @sql_service.count(filters)
      { products: [], context: { counts: counts } }
    end

    def execute_contextual_strategy(classification, context)
      # Filter previous products based on new criteria
      products = context[:previous_products] || []

      if classification[:filters].present?
        products = apply_contextual_filters(products, classification[:filters])
      end

      { products: products, context: context }
    end

    def execute_search_strategy(classification)
      results = @search_service.call(
        query: classification[:search_query],
        filters: classification[:filters]
      )

      products = results.map { |r| r[:product] }
      { products: products, context: {} }
    end

    def apply_contextual_filters(products, filters)
      products.select do |product|
        matches_filters?(product, filters)
      end
    end

    def matches_filters?(product, filters)
      return false if filters[:min_price] && product.price && product.price < filters[:min_price]
      return false if filters[:max_price] && product.price && product.price > filters[:max_price]
      return false if filters[:in_stock] == true && !product.in_stock
      return false if filters[:category] && product.category&.slug != filters[:category] && product.category&.name&.downcase != filters[:category]&.downcase
      return false if filters[:brand] && product.brand&.slug != filters[:brand] && product.brand&.name&.downcase != filters[:brand]&.downcase

      true
    end
  end
end
