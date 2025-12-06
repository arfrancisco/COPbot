class Message < ApplicationRecord
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
    # Use cosine similarity for semantic search with JSONB embeddings
    # Note: Old messages are automatically deleted by DeleteOldMessagesJob

    puts "    [Message.search_by_embedding] Total messages in DB: #{Message.count}"
    STDOUT.flush

    # Convert query embedding array to JSON string
    query_vector = query_embedding.map(&:to_f).to_json

    # Calculate cosine similarity using PostgreSQL
    # Cosine similarity = dot_product / (magnitude1 * magnitude2)
    sql = <<-SQL
      WITH query_vector AS (
        SELECT ?::jsonb AS vec
      ),
      similarities AS (
        SELECT
          messages.*,
          (
            SELECT SUM(
              (messages.embedding->idx)::text::float *
              (query_vector.vec->idx)::text::float
            )
            FROM generate_series(0, jsonb_array_length(messages.embedding) - 1) AS idx
          ) / (
            SQRT(
              (SELECT SUM(POWER((messages.embedding->idx)::text::float, 2))
               FROM generate_series(0, jsonb_array_length(messages.embedding) - 1) AS idx)
            ) *
            SQRT(
              (SELECT SUM(POWER((query_vector.vec->idx)::text::float, 2))
               FROM generate_series(0, jsonb_array_length(query_vector.vec) - 1) AS idx)
            )
          ) AS similarity
        FROM messages, query_vector
        WHERE messages.embedding IS NOT NULL
      )
      SELECT * FROM similarities
      ORDER BY similarity DESC NULLS LAST
      LIMIT ?
    SQL

    results = find_by_sql([sql, query_vector, limit])

    puts "    [Message.search_by_embedding] Query returned #{results.length} results"
    STDOUT.flush

    results
  rescue StandardError => e
    puts "    [Message.search_by_embedding] ❌ SQL Error: #{e.message}"
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
