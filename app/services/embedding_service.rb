class EmbeddingService
  EMBEDDING_MODEL = 'text-embedding-3-small'.freeze
  EMBEDDING_DIMENSION = 1536

  class << self
    def embed(text)
      return nil if text.blank?

      response = client.embeddings(
        parameters: {
          model: EMBEDDING_MODEL,
          input: text.strip
        }
      )

      embedding = response.dig('data', 0, 'embedding')
      
      if embedding.nil?
        Rails.logger.error("Failed to get embedding for text: #{text[0..50]}...")
        return nil
      end

      embedding
    rescue StandardError => e
      Rails.logger.error("Error generating embedding: #{e.message}")
      nil
    end

    private

    def client
      @client ||= OpenAI::Client.new
    end
  end
end

