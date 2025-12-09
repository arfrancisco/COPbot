class QueryLoggerService
  class << self
    # Start a new query log
    # Returns a UserQuery record that can be updated as the query progresses
    def start_query(query_text:, telegram_user_id: nil, telegram_chat_id: nil, username: nil)
      UserQuery.create!(
        query_text: query_text,
        telegram_user_id: telegram_user_id,
        telegram_chat_id: telegram_chat_id,
        username: username,
        queried_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.error("Error starting query log: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      nil
    end

    # Add search context information to the query log
    def add_search_context(log, results:, search_query: nil, context_text: nil)
      return unless log

      message_ids = results.respond_to?(:map) ? results.map(&:id) : []
      
      log.update(
        search_results_count: results.length,
        context_message_ids: message_ids,
        search_query_used: search_query,
        context_provided: context_text
      )
    rescue StandardError => e
      Rails.logger.error("Error adding search context to query log: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
    end

    # Complete the query log with the response
    def complete_query(log, response_text:, model: nil, temperature: nil, max_tokens: nil, usage: {})
      return unless log

      updates = {
        response_text: response_text,
        responded_at: Time.current,
        response_time_ms: log.response_time || calculate_response_time(log)
      }

      # Add OpenAI metadata if provided
      updates[:model_used] = model if model
      updates[:temperature] = temperature if temperature
      updates[:max_tokens] = max_tokens if max_tokens

      # Add token usage if provided
      if usage.is_a?(Hash)
        updates[:prompt_tokens] = usage[:prompt_tokens] || usage['prompt_tokens']
        updates[:completion_tokens] = usage[:completion_tokens] || usage['completion_tokens']
        updates[:total_tokens] = usage[:total_tokens] || usage['total_tokens']
      end

      log.update(updates)
    rescue StandardError => e
      Rails.logger.error("Error completing query log: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
    end

    # Log an error for the query
    def log_error(log, error)
      return unless log

      error_message = if error.is_a?(StandardError)
        "#{error.class}: #{error.message}"
      else
        error.to_s
      end

      log.update(
        error_message: error_message,
        responded_at: Time.current,
        response_time_ms: log.response_time || calculate_response_time(log)
      )
    rescue StandardError => e
      Rails.logger.error("Error logging error to query log: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
    end

    private

    # Calculate response time in milliseconds
    def calculate_response_time(log)
      return nil unless log.queried_at

      ((Time.current - log.queried_at) * 1000).to_i
    end
  end
end

