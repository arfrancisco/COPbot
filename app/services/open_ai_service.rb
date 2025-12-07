class OpenAiService
  class << self
    def generate_response(query, context)
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o',  # Using full gpt-4o for better multilingual understanding
          messages: [
            {
              role: 'system',
              content: <<~PROMPT
                You are a helpful concierge assistant for a community.

                Your task is to answer questions based ONLY on the provided context from recent messages.

                CRITICAL - Language Rules (MUST FOLLOW):
                - ALWAYS respond in the SAME language as the question
                - Filipino/Tagalog question → Filipino/Tagalog response
                - English question → English response
                - Taglish (mixed) question → Taglish response
                - NEVER default to English unless the question is in English
                - Match the tone, formality, and style of the question
                - Feel free to use emojis to make responses more friendly and engaging

                Important Rules:
                1. Only use information from the provided context
                2. If the context doesn't contain relevant information, say: "I don't have that information in the recent messages."
                3. Be concise and direct
                4. Quote or reference specific messages when appropriate
                5. Don't make assumptions or add information not in the context
              PROMPT
            },
            {
              role: 'user',
              content: <<~MESSAGE
                Here are recent messages that might be relevant:

                #{context}

                ---

                Question: #{query}
              MESSAGE
            }
          ],
          temperature: 0.3,  # Lower temperature for more factual, accurate responses
          max_tokens: 1500     # Slightly more tokens for detailed answers
        }
      )

      response.dig('choices', 0, 'message', 'content') || 'No answer generated.'
    rescue StandardError => e
      Rails.logger.error("Error generating response: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      "Sorry, I couldn't generate a response at this time. Error: #{e.message}"
    end
  end
end
