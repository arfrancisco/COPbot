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
  def self.search_by_embedding(query_embedding, limit: 10, similarity_threshold: 0.5, query_text: nil)
    # Use pgvector for FAST cosine similarity search
    # This is 100x+ faster than the old JSONB approach

    puts "    [Message.search_by_embedding] Total messages in DB: #{Message.count}"
    STDOUT.flush

    # Extract keywords from query for hybrid search
    keywords = query_text&.downcase&.split(/\s+/) || []

    # Use pgvector's nearest_neighbors method for lightning-fast search
    # Fetch more results initially to apply similarity filtering
    # Cosine distance ranges from 0 (identical) to 2 (opposite)
    # Distance < 0.3 = very similar, < 0.5 = similar, < 0.7 = somewhat similar
    candidates = Message
      .nearest_neighbors(:embedding_vector, query_embedding, distance: "cosine")
      .limit(limit * 5)  # Get 5x limit for filtering
      .to_a

    # Hybrid scoring: combine semantic similarity with keyword matching
    scored_candidates = candidates.map do |msg|
      # Start with semantic similarity (convert distance to similarity)
      semantic_score = 1.0 - msg.neighbor_distance

      # Keyword boost: check how many query keywords appear in the message
      keyword_score = 0.0
      if keywords.any?
        text_lower = msg.text.downcase
        matched_keywords = keywords.count { |kw| text_lower.include?(kw) }
        keyword_score = (matched_keywords.to_f / keywords.length) * 0.3  # Up to 30% boost

        # Extra boost for longer messages with keyword matches
        # (helps surface detailed documents that mention the topic)
        if matched_keywords > 0 && msg.text.length > 500
          keyword_score += 0.2
        end
      end

      combined_score = semantic_score + keyword_score

      { message: msg, score: combined_score, distance: msg.neighbor_distance }
    end

    # Sort by combined score (higher is better)
    scored_candidates.sort_by! { |sc| -sc[:score] }

    # Filter by similarity threshold (convert to distance for comparison)
    max_distance = 1.0 - similarity_threshold

    results = scored_candidates
      .select { |sc| sc[:distance] <= max_distance }
      .first(limit)
      .map { |sc| sc[:message] }

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
