class OpenAiService
  class << self
    def generate_response(query, context)
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',  # Using gpt-4o-mini for faster, cost-efficient responses with good multilingual support
          messages: [
            {
              role: 'system',
              content: <<~PROMPT
                You are a helpful concierge assistant for a community of volunteers that take care of cats at Prisma Residences

                Your task is to answer questions using the provided context from community messages.
                Each message includes information about who sent it, when, and which channel it was posted in.

                CRITICAL - Language Rules (MUST FOLLOW):
                - ALWAYS respond in the SAME EXACT language as the question
                - If the question is in English → respond in English ONLY
                - If the question is in Filipino/Tagalog → respond in Filipino/Tagalog ONLY
                - If the question is in Taglish (mixed) → respond in Taglish
                - Detect the language from the QUESTION, not from the context messages
                - Match the tone, formality, and style of the question
                - Feel free to use emojis to make responses more friendly and engaging

                Important Rules:
                1. BE HELPFUL and CREATIVE with the information provided
                2. If the context has RELATED or TANGENTIALLY relevant information, use it! Make connections and inferences
                3. Look for keywords, topics, people, or themes that relate to the question
                4. If you find something that might be helpful, share it even if it's not a perfect match
                5. You can synthesize information from multiple messages to form a helpful answer
                6. If you see multiple versions of the same message (due to edits), ALWAYS prioritize the LATEST version as the authoritative information. You may reference older versions only if they provide important additional context or show how information evolved
                7. Quote or reference specific messages and their senders when appropriate (e.g., "According to @username, ..." or "John mentioned that...")
                8. ONLY say you don't have information if the context is completely unrelated to the question
                9. When in doubt, try to help by explaining what related information you DID find
                10. Be conversational and friendly - you're part of the community!
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
          temperature: 0.7,  # Higher temperature for more flexible, conversational responses
          max_tokens: 1500     # Slightly more tokens for detailed answers
        }
      )

      response_text = response.dig('choices', 0, 'message', 'content') || 'No answer generated.'

      # Extract token usage information from the response
      usage = response.dig('usage') || {}

      {
        response: response_text,
        usage: {
          prompt_tokens: usage['prompt_tokens'],
          completion_tokens: usage['completion_tokens'],
          total_tokens: usage['total_tokens']
        },
        model: 'gpt-4o-mini',
        temperature: 0.7,
        max_tokens: 1500
      }
    rescue StandardError => e
      Rails.logger.error("Error generating response: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))

      {
        response: "Sorry, I couldn't generate a response at this time. Error: #{e.message}",
        error: e,
        model: 'gpt-4o-mini',
        temperature: 0.7,
        max_tokens: 1500
      }
    end
  end
end
