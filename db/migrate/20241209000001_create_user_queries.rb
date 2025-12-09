class CreateUserQueries < ActiveRecord::Migration[7.0]
  def change
    create_table :user_queries do |t|
      # User Information
      t.bigint :telegram_user_id
      t.bigint :telegram_chat_id
      t.string :username

      # Query & Response
      t.text :query_text, null: false
      t.text :response_text
      t.text :error_message

      # Search Context
      t.integer :search_results_count
      t.integer :context_message_ids, array: true, default: []
      t.text :context_provided
      t.text :search_query_used

      # OpenAI API Metadata
      t.string :model_used, default: 'gpt-4o'
      t.decimal :temperature
      t.integer :max_tokens
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens

      # Timing & Performance
      t.datetime :queried_at, null: false
      t.datetime :responded_at
      t.integer :response_time_ms

      t.timestamps
    end

    # Indexes for performance
    add_index :user_queries, :telegram_user_id
    add_index :user_queries, :telegram_chat_id
    add_index :user_queries, :queried_at
    add_index :user_queries, :model_used
  end
end

