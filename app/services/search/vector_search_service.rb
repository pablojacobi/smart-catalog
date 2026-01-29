# frozen_string_literal: true

module Search
  # Service for semantic vector search using pgvector
  # Finds documents similar to a query using embedding similarity
  class VectorSearchService
    include CallableService

    DEFAULT_LIMIT = 50
    DEFAULT_MIN_SCORE = 0.65

    def initialize(embeddings_service: nil)
      @embeddings_service = embeddings_service || Gemini::EmbeddingsService
    end

    # Search for similar documents using vector similarity
    #
    # @param query [String] Search query text
    # @param limit [Integer] Maximum results to return
    # @param min_score [Float] Minimum similarity score (0-1)
    # @return [Array<Hash>] Documents with similarity scores
    def call(query, limit: DEFAULT_LIMIT, min_score: DEFAULT_MIN_SCORE)
      return [] if query.blank?

      Rails.logger.info("[VectorSearch] Query: '#{query.truncate(60)}', limit: #{limit}")
      start_time = Time.current

      # Generate query embedding
      embedding = @embeddings_service.call(query)
      return [] if embedding.blank?

      # Search using pgvector neighbor gem
      # neighbor_distance returns cosine distance (0 = identical, 2 = opposite)
      # Convert to similarity: 1 - (distance / 2) for 0-1 scale
      results = Document
        .where.not(embedding: nil)
        .nearest_neighbors(:embedding, embedding, distance: 'cosine')
        .limit(limit * 2) # Fetch extra to filter by score

      # Filter and format results
      formatted = results.filter_map do |doc|
        similarity = 1.0 - doc.neighbor_distance
        next if similarity < min_score

        {
          document: doc,
          score: similarity.round(4),
          source: 'vector'
        }
      end.first(limit)

      duration = Time.current - start_time
      Rails.logger.info("[VectorSearch] Found #{formatted.length} results in #{duration.round(2)}s")

      formatted
    end
  end
end
