class TelegramBotService
  class << self
    def process_channel_message(message)
      return unless message.chat.type == 'channel'

      text = extract_text(message)
      return if text.blank?

      # Generate embedding for the message
      embedding = EmbeddingService.embed(text)
      return if embedding.nil?

      # Store the message in the database
      Message.create!(
        channel_id: message.chat.id,
        text: text,
        message_timestamp: Time.at(message.date),
        embedding: embedding
      )

      Rails.logger.info("Saved channel message: #{text[0..60]}...")
    rescue StandardError => e
      Rails.logger.error("Error processing channel message: #{e.message}")
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
      response = generate_response(query, context)

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

    def generate_response(query, context)
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'You are a helpful concierge assistant. Answer the user\'s question using ONLY the provided context. ' \
                       'Respond in the same language as the user\'s question. Support English, Filipino/Tagalog, and Taglish (mixed Filipino-English). ' \
                       'If the context doesn\'t contain relevant information, politely say you don\'t have that information.'
            },
            {
              role: 'assistant',
              content: "Context from relevant messages:\n\n#{context}"
            },
            {
              role: 'user',
              content: query
            }
          ],
          temperature: 0.7,
          max_tokens: 500
        }
      )

      response.dig('choices', 0, 'message', 'content') || 'No answer generated.'
    rescue StandardError => e
      Rails.logger.error("Error generating response: #{e.message}")
      "Sorry, I couldn't generate a response at this time."
    end
  end
end

