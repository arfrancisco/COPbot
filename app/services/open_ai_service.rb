class OpenAiService
  class << self
    def generate_response(query, context)
      client = OpenAI::Client.new

      response = client.chat(
        parameters: {
          model: 'gpt-4o-nano',
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
