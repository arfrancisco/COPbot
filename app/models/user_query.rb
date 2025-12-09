class UserQuery < ApplicationRecord
  # Validations
  validates :query_text, presence: true
  validates :queried_at, presence: true

  # Scopes
  scope :recent, -> { order(queried_at: :desc) }
  scope :by_user, ->(telegram_user_id) { where(telegram_user_id: telegram_user_id) }
  scope :by_chat, ->(telegram_chat_id) { where(telegram_chat_id: telegram_chat_id) }
  scope :with_errors, -> { where.not(error_message: nil) }
  scope :successful, -> { where(error_message: nil).where.not(response_text: nil) }
  scope :by_model, ->(model) { where(model_used: model) }
  scope :within_timeframe, ->(start_time, end_time) { where(queried_at: start_time..end_time) }
  
  # Queries where bot couldn't find relevant information
  # These are queries with zero search results or responses indicating no information available
  scope :no_results_found, -> { 
    where(search_results_count: 0)
      .or(where("response_text LIKE ?", "%couldn't find any relevant messages%"))
      .or(where("response_text LIKE ?", "%don't have any messages indexed%"))
  }

  # Instance methods
  
  # Calculate response time in milliseconds
  def response_time
    return response_time_ms if response_time_ms.present?
    return nil unless queried_at && responded_at
    
    ((responded_at - queried_at) * 1000).to_i
  end

  # Check if query was successful
  def success?
    error_message.nil? && response_text.present?
  end

  # Check if the bot couldn't find relevant information
  def no_results?
    search_results_count == 0 ||
      response_text&.include?("couldn't find any relevant messages") ||
      response_text&.include?("don't have any messages indexed")
  end

  # Estimate cost based on token usage
  # GPT-4o pricing (as of Dec 2024):
  # - Input: $2.50 per 1M tokens
  # - Output: $10.00 per 1M tokens
  def cost_estimate
    return nil unless prompt_tokens && completion_tokens
    
    input_cost = (prompt_tokens / 1_000_000.0) * 2.50
    output_cost = (completion_tokens / 1_000_000.0) * 10.00
    
    input_cost + output_cost
  end

  # Get the actual Message records that were used as context
  def context_messages
    return Message.none if context_message_ids.blank?
    
    Message.where(id: context_message_ids)
  end

  # Human-readable summary of the query
  def summary
    status = if error_message.present?
      "Error"
    elsif response_text.present?
      "Success"
    else
      "Pending"
    end

    truncated_query = query_text.length > 50 ? "#{query_text[0..47]}..." : query_text
    "#{status} | #{truncated_query} | #{username || telegram_user_id}"
  end
end

