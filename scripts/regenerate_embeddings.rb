#!/usr/bin/env ruby
# Script to regenerate embeddings for all existing messages
# Usage: bundle exec ruby scripts/regenerate_embeddings.rb

require_relative '../config/environment'

class EmbeddingRegenerator
  def initialize
    @success_count = 0
    @error_count = 0
    @skipped_count = 0
  end

  def regenerate_all
    total_messages = Message.count
    puts "🔄 Starting embedding regeneration for #{total_messages} messages"
    puts "=" * 80

    if total_messages == 0
      puts "❌ No messages found in database"
      return
    end

    puts "Using model: #{EmbeddingService::EMBEDDING_MODEL}"
    puts "Embedding dimension: #{EmbeddingService::EMBEDDING_DIMENSION}"
    puts ""

    Message.find_each.with_index do |message, index|
      print "\rProcessing message #{index + 1}/#{total_messages}... "
      STDOUT.flush

      regenerate_embedding(message)

      # Add a small delay every 10 messages to avoid rate limiting
      sleep(0.1) if (index + 1) % 10 == 0
    end

    puts "\n"
    puts "=" * 80
    puts "✅ Regeneration complete!"
    puts "   Success: #{@success_count}"
    puts "   Errors: #{@error_count}"
    puts "   Skipped: #{@skipped_count}"
    puts "   Total: #{total_messages}"
  end

  private

  def regenerate_embedding(message)
    # Skip if message has no text
    if message.text.blank?
      @skipped_count += 1
      return
    end

    # Generate new embedding
    new_embedding = EmbeddingService.embed(message.text)

    if new_embedding.nil?
      @error_count += 1
      puts "\n❌ Failed to generate embedding for message #{message.id}"
      return
    end

    # Validate embedding dimension
    if new_embedding.length != EmbeddingService::EMBEDDING_DIMENSION
      @error_count += 1
      puts "\n❌ Invalid embedding dimension for message #{message.id}: expected #{EmbeddingService::EMBEDDING_DIMENSION}, got #{new_embedding.length}"
      return
    end

    # Update both JSONB and vector columns
    message.update_columns(
      embedding: new_embedding,
      embedding_vector: new_embedding
    )
    @success_count += 1

  rescue StandardError => e
    @error_count += 1
    puts "\n❌ Error processing message #{message.id}: #{e.message}"
    Rails.logger.error("Error regenerating embedding for message #{message.id}: #{e.message}")
  end
end

# Main execution
if __FILE__ == $0
  puts "🤖 Embedding Regenerator"
  puts "This will regenerate embeddings for ALL messages using #{EmbeddingService::EMBEDDING_MODEL}"
  puts ""
  puts "⚠️  WARNING: This will:"
  puts "   - Make API calls to OpenAI for each message"
  puts "   - Update all message embeddings in the database"
  puts "   - May take some time for large datasets"
  puts ""
  print "Continue? (y/n): "

  response = STDIN.gets.chomp.downcase

  if response == 'y' || response == 'yes'
    puts ""
    regenerator = EmbeddingRegenerator.new
    regenerator.regenerate_all
    puts "\n✨ Complete!"
  else
    puts "❌ Cancelled"
  end
end
