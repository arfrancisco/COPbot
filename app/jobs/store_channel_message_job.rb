class StoreChannelMessageJob < ApplicationJob
  queue_as :default

  def perform(channel_id, channel_name, text, message_timestamp, sender_id = nil, sender_name = nil, sender_username = nil)
    puts "[StoreChannelMessageJob] Starting to process message: #{text[0..60]}..."
    STDOUT.flush

    # Generate embedding for the message
    embedding = EmbeddingService.embed(text)

    if embedding.nil?
      puts "[StoreChannelMessageJob] Failed to generate embedding, skipping message"
      STDOUT.flush
      return
    end

    puts "[StoreChannelMessageJob] Embedding generated (#{embedding.class}, length: #{embedding.length}), saving to database..."
    STDOUT.flush

    # Store the message in the database with both JSONB and vector embeddings
    Message.create!(
      channel_id: channel_id,
      channel_name: channel_name,
      text: text,
      message_timestamp: message_timestamp,
      embedding: embedding,
      embedding_vector: embedding,  # Populate pgvector column for fast similarity search
      sender_id: sender_id,
      sender_name: sender_name,
      sender_username: sender_username
    )

    puts "[StoreChannelMessageJob] ✓ Successfully saved message to database"
    STDOUT.flush
    Rails.logger.info("Saved channel message: #{text[0..60]}...")
  rescue StandardError => e
    puts "[StoreChannelMessageJob] ERROR: #{e.message}"
    puts e.backtrace.join("\n")
    STDOUT.flush
    Rails.logger.error("Error storing channel message: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
