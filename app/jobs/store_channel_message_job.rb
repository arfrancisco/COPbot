class StoreChannelMessageJob < ApplicationJob
  queue_as :default

  def perform(channel_id, channel_name, text, message_timestamp)
    puts "[StoreChannelMessageJob] Starting to process message: #{text[0..60]}..."
    STDOUT.flush

    # Generate embedding for the message
    embedding = EmbeddingService.embed(text)

    if embedding.nil?
      puts "[StoreChannelMessageJob] Failed to generate embedding, skipping message"
      STDOUT.flush
      return
    end

    puts "[StoreChannelMessageJob] Embedding generated, saving to database..."
    STDOUT.flush

    # Store the message in the database
    Message.create!(
      channel_id: channel_id,
      channel_name: channel_name,
      text: text,
      message_timestamp: message_timestamp,
      embedding: embedding
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
