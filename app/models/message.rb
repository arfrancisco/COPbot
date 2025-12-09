class Message < ApplicationRecord
  # pgvector integration with HNSW indexing for fast similarity search
  has_neighbors :embedding_vector, dimensions: 1536, normalize: false

  # Validations
  validates :channel_id, presence: true
  validates :text, presence: true
  validates :message_timestamp, presence: true
  validates :embedding, presence: true
  # sender_id and sender_name are optional to support legacy messages

  # Scopes
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :ordered, -> { order(message_timestamp: :desc) }

  # Class methods
  def self.search_by_embedding(query_embedding, limit: 10, max_distance: 1.2, query_text: nil)
    # Use pgvector for FAST cosine similarity search with pure relevance-based ranking
    # This is 100x+ faster than the old JSONB approach

    puts "    [Message.search_by_embedding] Total messages in DB: #{Message.count}"
    STDOUT.flush

    # Extract keywords from query for hybrid search
    # No stop word filtering to support Filipino/Tagalog and Taglish queries
    keywords = query_text&.downcase&.split(/\s+/) || []

    # Use pgvector's nearest_neighbors method for lightning-fast search
    # Fetch significantly more results initially to ensure best relevance across entire history
    # Cosine distance ranges from 0 (identical) to 2 (opposite)
    # Distance < 0.3 = very similar, < 0.5 = similar, < 0.8 = somewhat similar, < 1.2 = possibly relevant
    candidates = Message
      .nearest_neighbors(:embedding_vector, query_embedding, distance: "cosine")
      .limit(limit * 15)  # Get 15x limit to cast an even wider net for more heuristic search
      .to_a

    # Hybrid scoring: combine semantic similarity with keyword matching
    # Prioritize pure relevance - no recency bias
    scored_candidates = candidates.map do |msg|
      # Start with semantic similarity (convert distance to similarity)
      # Weight semantic similarity heavily (80% of base score)
      semantic_score = (1.0 - msg.neighbor_distance) * 0.8

      # Keyword boost: check how many query keywords appear in the message
      keyword_score = 0.0
      if keywords.any?
        text_lower = msg.text.downcase
        
        # Count full keyword matches
        matched_keywords = keywords.count { |kw| text_lower.include?(kw) }
        keyword_score = (matched_keywords.to_f / keywords.length) * 0.8  # Up to 80% boost for keyword matches

        # Extra boost for exact phrase matches (highest relevance signal)
        if query_text && text_lower.include?(query_text.downcase)
          keyword_score += 1.0  # Strong boost for exact phrase match
        end

        # Boost for longer messages with keyword matches
        # (helps surface detailed documents that mention the topic)
        if matched_keywords > 0 && msg.text.length > 500
          keyword_score += 0.6
        end
        
        # Partial word matching - helps with plurals, verb forms, etc.
        partial_matches = keywords.count do |kw|
          text_lower.split(/\s+/).any? { |word| word.start_with?(kw) || kw.start_with?(word) }
        end
        if partial_matches > matched_keywords
          keyword_score += (partial_matches - matched_keywords).to_f / keywords.length * 0.3
        end
      end

      combined_score = semantic_score + keyword_score

      { message: msg, score: combined_score, distance: msg.neighbor_distance }
    end

    # Sort by combined relevance score (higher is better)
    # NO recency factor - pure relevance-based ranking
    scored_candidates.sort_by! { |sc| -sc[:score] }

    # Filter by max distance threshold (lower distance = more similar)
    results = scored_candidates
      .select { |sc| sc[:distance] <= max_distance }
      .first(limit)
      .map { |sc| sc[:message] }

    puts "    [Message.search_by_embedding] Filtered #{candidates.length} candidates to #{results.length} results (max_distance: #{max_distance})"
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

  def sender_display_name
    # Display both name and username when available
    if sender_name.present? && sender_username.present?
      "#{sender_name} (@#{sender_username})"
    elsif sender_username.present?
      "@#{sender_username}"
    elsif sender_name.present?
      sender_name
    else
      "User #{sender_id}"
    end
  end
end
