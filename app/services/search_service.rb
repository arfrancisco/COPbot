class SearchService
  class << self
    def search(query, limit: 10)
      return Message.none if query.blank?

      # Generate embedding for the search query
      query_embedding = EmbeddingService.embed(query)
      
      return Message.none if query_embedding.nil?

      # Search for similar messages using vector similarity
      Message.search_by_embedding(query_embedding, limit: limit)
    rescue StandardError => e
      Rails.logger.error("Error performing search: #{e.message}")
      Message.none
    end
  end
end

