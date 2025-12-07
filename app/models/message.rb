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
  def self.search_by_embedding(query_embedding, limit: 10, similarity_threshold: 0.5)
    # Use pgvector for FAST cosine similarity search
    # This is 100x+ faster than the old JSONB approach

    puts "    [Message.search_by_embedding] Total messages in DB: #{Message.count}"
    STDOUT.flush

    # Use pgvector's nearest_neighbors method for lightning-fast search
    # Fetch more results initially to apply similarity filtering
    # Cosine distance ranges from 0 (identical) to 2 (opposite)
    # Distance < 0.3 = very similar, < 0.5 = similar, < 0.7 = somewhat similar
    candidates = Message
      .nearest_neighbors(:embedding_vector, query_embedding, distance: "cosine")
      .limit(limit * 5)  # Get 5x limit for filtering
      .to_a

    # Filter by similarity threshold (lower distance = more similar)
    # Convert similarity_threshold (0-1, higher = more similar) to distance (0-2, lower = more similar)
    max_distance = 1.0 - similarity_threshold

    results = candidates.select do |msg|
      msg.neighbor_distance <= max_distance
    end.first(limit)

    puts "    [Message.search_by_embedding] Filtered #{candidates.length} candidates to #{results.length} results (threshold: #{similarity_threshold})"
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
