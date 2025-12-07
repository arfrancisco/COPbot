class SearchService
  class << self
    def search(query, limit: 10)
      return Message.none if query.blank?

      puts "  [SearchService] Generating embedding for query..."
      STDOUT.flush

      # Generate embedding for the search query
      query_embedding = EmbeddingService.embed(query)

      if query_embedding.nil?
        puts "  [SearchService] ❌ Failed to generate embedding"
        STDOUT.flush
        return Message.none
      end

      puts "  [SearchService] ✅ Embedding generated, searching..."
      STDOUT.flush

      # Search for similar messages using vector similarity
      # Pass the query text for hybrid keyword boosting
      results = Message.search_by_embedding(query_embedding, limit: limit, query_text: query)

      puts "  [SearchService] Found #{results.length} results"
      STDOUT.flush

      results
    rescue StandardError => e
      Rails.logger.error("Error performing search: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      puts "  [SearchService] ❌ Error: #{e.message}"
      STDOUT.flush

      Message.none
    end
  end
end
