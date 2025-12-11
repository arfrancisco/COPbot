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

      # Start logging the query
      query_log = QueryLoggerService.start_query(
        query_text: query,
        telegram_user_id: message.from&.id,
        telegram_chat_id: message.chat.id,
        username: extract_sender_name(message.from)
      )

      # Search for relevant messages with more results for better context
      results = SearchService.search(query, limit: 25)

      puts "📊 Search returned #{results.length} results"
      STDOUT.flush

      if results.empty?
        puts "❌ No results found"
        STDOUT.flush

        # Check if there are any messages in the database at all
        total_messages = Message.count
        puts "📈 Total messages in database: #{total_messages}"
        STDOUT.flush

        response_text = if total_messages == 0
          "I don't have any messages indexed yet. Make sure I'm added to the channels you want me to search."
        else
          "I couldn't find any relevant messages about that. Try rephrasing your question or asking about something else!"
        end

        # Log the response (even though no search results)
        QueryLoggerService.complete_query(query_log,
          response_text: response_text,
          model: 'gpt-4o',
          temperature: 0.7,
          max_tokens: 1500
        )

        bot.api.send_message(
          chat_id: message.chat.id,
          reply_to_message_id: message.message_id,
          text: response_text
        )
        return
      end

      puts "✅ Found relevant results, generating response..."
      STDOUT.flush

      # Build context from search results with metadata
      # Include similarity hints to help the AI understand relevance
      context = results.map.with_index do |msg, idx|
        timestamp = msg.message_timestamp.in_time_zone('Asia/Manila').strftime("%b %d, %Y at %I:%M %p")
        sender = msg.sender_display_name
        # Note: neighbor_distance is available from the search if we're within a search context
        relevance_note = if idx < 5
          "(highly relevant)"
        elsif idx < 10
          "(relevant)"
        else
          "(possibly relevant)"
        end
        "[Message #{idx + 1}] #{relevance_note} From: #{sender} (#{timestamp} - #{msg.channel_name}):\n#{msg.text}"
      end.join("\n\n---\n\n")

      # Log search context
      QueryLoggerService.add_search_context(query_log,
        results: results,
        search_query: query,
        context_text: context
      )

      # Generate response using OpenAI
      ai_response = OpenAiService.generate_response(query, context)

      # Handle response based on whether it's a hash (new format) or string (error fallback)
      response_text = ai_response.is_a?(Hash) ? ai_response[:response] : ai_response

      # Log the completion with token usage
      if ai_response.is_a?(Hash) && !ai_response[:error]
        QueryLoggerService.complete_query(query_log,
          response_text: response_text,
          model: ai_response[:model],
          temperature: ai_response[:temperature],
          max_tokens: ai_response[:max_tokens],
          usage: ai_response[:usage]
        )
      elsif ai_response.is_a?(Hash) && ai_response[:error]
        QueryLoggerService.log_error(query_log, ai_response[:error])
      else
        # Legacy string response
        QueryLoggerService.complete_query(query_log,
          response_text: response_text,
          model: 'gpt-4o',
          temperature: 0.7,
          max_tokens: 1500
        )
      end

      # Send response back to user as a reply
      bot.api.send_message(
        chat_id: message.chat.id,
        reply_to_message_id: message.message_id,
        text: response_text
      )
    rescue StandardError => e
      Rails.logger.error("Error processing user query: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      puts "❌ Error processing query: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      STDOUT.flush

      # Log the error
      QueryLoggerService.log_error(query_log, e) if query_log

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
