class Message < ApplicationRecord
  # pgvector integration with HNSW indexing for fast similarity search
  has_neighbors :embedding_vector, dimensions: 1536, normalize: false

  # Validations
  validates :channel_id, presence: true
  validates :text, presence: true
  validates :message_timestamp, presence: true
  validates :embedding, presence: true

  # Scopes
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :ordered, -> { order(message_timestamp: :desc) }

  # Class methods
  def self.search_by_embedding(query_embedding, limit: 10)
    # Use pgvector for FAST cosine similarity search
    # This is 100x+ faster than the old JSONB approach

    puts "    [Message.search_by_embedding] Total messages in DB: #{Message.count}"
    STDOUT.flush

    # Use pgvector's nearest_neighbors method for lightning-fast search
    # The <=> operator uses cosine distance (which is what we want)
    results = Message
      .nearest_neighbors(:embedding_vector, query_embedding, distance: "cosine")
      .limit(limit)
      .to_a

    puts "    [Message.search_by_embedding] Query returned #{results.length} results"
    STDOUT.flush

    results
  rescue StandardError => e
    puts "    [Message.search_by_embedding] ❌ Error: #{e.message}"
    STDOUT.flush
    Rails.logger.error("Error in search_by_embedding: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    []
  end

  # Instance methods
  def age_in_days
    ((Time.current - message_timestamp) / 1.day).to_i
  end
end
