class EmbeddingService
  EMBEDDING_MODEL = 'text-embedding-3-large'.freeze
  EMBEDDING_DIMENSION = 1536  # Reduced from 3072 to enable HNSW indexing

  class << self
    def embed(text)
      return nil if text.blank?

      response = client.embeddings(
        parameters: {
          model: EMBEDDING_MODEL,
          input: text.strip,
          dimensions: EMBEDDING_DIMENSION  # Request reduced dimensions from OpenAI
        }
      )

      # Handle both hash and object response formats
      embedding = if response.is_a?(Hash)
                    response.dig('data', 0, 'embedding')
                  else
                    response.dig('data', 0, 'embedding')
                  end

      if embedding.nil? || !embedding.is_a?(Array) || embedding.length != EMBEDDING_DIMENSION
        Rails.logger.error("Invalid embedding response for text: #{text[0..50]}...")
        Rails.logger.error("Response: #{response.inspect[0..200]}")
        return nil
      end

      embedding
    rescue StandardError => e
      Rails.logger.error("Error generating embedding: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      nil
    end

    private

    def client
      @client ||= OpenAI::Client.new
    end
  end
end
