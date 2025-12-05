class Message < ApplicationRecord
  # Validations
  validates :channel_id, presence: true
  validates :text, presence: true
  validates :message_timestamp, presence: true
  validates :embedding, presence: true

  # Scopes
  scope :recent, -> { where('message_timestamp >= ?', 90.days.ago) }
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :ordered, -> { order(message_timestamp: :desc) }

  # Class methods
  def self.search_by_embedding(query_embedding, limit: 10)
    # Use cosine distance for semantic search
    # Only search messages from the last 90 days
    recent
      .order(Arel.sql("embedding <=> '#{sanitize_sql_array([query_embedding.to_s])}'"))
      .limit(limit)
  end

  # Instance methods
  def age_in_days
    ((Time.current - message_timestamp) / 1.day).to_i
  end

  def old?
    message_timestamp < 90.days.ago
  end
end

