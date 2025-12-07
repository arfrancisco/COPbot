class TelegramBotService
  class << self
    def process_channel_message(message)
      return unless ['channel', 'supergroup', 'group'].include?(message.chat.type)

      text = extract_text(message)
      return if text.blank?

      # Build channel identifier and name
      if message.is_topic_message && message.message_thread_id
        channel_id = "#{message.chat.id}_#{message.message_thread_id}"
        # Try to get topic name if available
        topic_name = extract_topic_name(message)
        channel_name = "#{topic_name || "Topic #{message.message_thread_id}"}"
      else
        channel_id = message.chat.id.to_s
        channel_name = "General"
      end

      # Extract sender information
      sender_id = message.from&.id&.to_s
      sender_name = extract_sender_name(message.from)
      sender_username = message.from&.username

      # Enqueue background job to store the message
      # Using perform_now for immediate processing to ensure messages are stored
      StoreChannelMessageJob.perform_now(
        channel_id,
        channel_name,
        text,
        Time.at(message.date),
        sender_id,
        sender_name,
        sender_username
      )

      Rails.logger.info("Processed channel message: #{text[0..60]}...")
    rescue StandardError => e
      Rails.logger.error("Error enqueuing channel message: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    def process_user_query(bot, message, query)
      return if query.blank?

      puts "🔍 Processing query: '#{query}'"
      STDOUT.flush

      # Search for relevant messages with more results for better context
      results = SearchService.search(query, limit: 20)

      puts "📊 Search returned #{results.length} results"
      STDOUT.flush

      if results.empty?
        puts "❌ No results found"
        STDOUT.flush

        # Check if there are any messages in the database at all
        total_messages = Message.count
        puts "📈 Total messages in database: #{total_messages}"
        STDOUT.flush

        bot.api.send_message(
          chat_id: message.chat.id,
          reply_to_message_id: message.message_id,
          text: "I couldn't find any relevant information about that."
        )
        return
      end

      puts "✅ Found relevant results, generating response..."
      STDOUT.flush

      # Build context from search results with metadata
      context = results.map.with_index do |msg, idx|
        timestamp = msg.message_timestamp.strftime("%b %d, %Y")
        sender = msg.sender_display_name
        "[Message #{idx + 1}] From: #{sender} (#{timestamp} - #{msg.channel_name}):\n#{msg.text}"
      end.join("\n\n---\n\n")

      # Generate response using OpenAI
      response = OpenAiService.generate_response(query, context)

      # Send response back to user as a reply
      bot.api.send_message(
        chat_id: message.chat.id,
        reply_to_message_id: message.message_id,
        text: response
      )
    rescue StandardError => e
      Rails.logger.error("Error processing user query: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      puts "❌ Error processing query: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      STDOUT.flush

      bot.api.send_message(
        chat_id: message.chat.id,
        reply_to_message_id: message.message_id,
        text: "Sorry, I encountered an error processing your request."
      )
    end

    private

    def extract_text(message)
      message.text || message.caption || ''
    end

    def extract_sender_name(from_user)
      return nil unless from_user

      # Build full name from first_name + last_name
      if from_user.first_name.present?
        full_name = from_user.first_name
        full_name += " #{from_user.last_name}" if from_user.last_name.present?
        full_name
      else
        nil
      end
    end

    def extract_topic_name(message)
      # Check if this is a reply and the replied message created the topic
      if message.reply_to_message&.forum_topic_created
        message.reply_to_message.forum_topic_created.name
      end
    end
  end
end
