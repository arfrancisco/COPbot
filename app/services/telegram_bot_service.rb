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

      # Enqueue background job to store the message
      StoreChannelMessageJob.perform_later(
        channel_id,
        channel_name,
        text,
        Time.at(message.date)
      )

      Rails.logger.info("Enqueued channel message for processing: #{text[0..60]}...")
    rescue StandardError => e
      Rails.logger.error("Error enqueuing channel message: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    def process_user_query(bot, message, query)
      return if query.blank?

      # Search for relevant messages
      results = SearchService.search(query, limit: 8)

      if results.empty?
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "I couldn't find any relevant information about that."
        )
        return
      end

      # Build context from search results
      context = results.map(&:text).join("\n\n---\n\n")

      # Generate response using OpenAI
      response = OpenAiService.generate_response(query, context)

      # Send response back to user
      bot.api.send_message(
        chat_id: message.chat.id,
        text: response
      )
    rescue StandardError => e
      Rails.logger.error("Error processing user query: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Sorry, I encountered an error processing your request."
      )
    end

    private

    def extract_text(message)
      message.text || message.caption || ''
    end

    def extract_topic_name(message)
      # Check if this is a reply and the replied message created the topic
      if message.reply_to_message&.forum_topic_created
        message.reply_to_message.forum_topic_created.name
      end
    end
  end
end
