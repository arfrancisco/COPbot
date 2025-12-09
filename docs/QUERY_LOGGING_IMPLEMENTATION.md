# Query Logging Implementation

## Overview

A comprehensive query logging system has been implemented to store all user queries, AI responses, search context, and debugging metadata. This will help with debugging, analysis, and monitoring of the bot's performance.

## What Was Implemented

### 1. Database Migration ✅
**File:** `db/migrate/20241209000001_create_user_queries.rb`

Created the `user_queries` table with the following fields:
- **User Information:** telegram_user_id, telegram_chat_id, username
- **Query & Response:** query_text, response_text, error_message
- **Search Context:** search_results_count, context_message_ids (array), context_provided, search_query_used
- **OpenAI Metadata:** model_used, temperature, max_tokens, prompt_tokens, completion_tokens, total_tokens
- **Timing:** queried_at, responded_at, response_time_ms
- **Indexes:** On telegram_user_id, telegram_chat_id, queried_at, and model_used

### 2. UserQuery Model ✅
**File:** `app/models/user_query.rb`

Features:
- Validations for required fields (query_text, queried_at)
- Scopes: `recent`, `by_user`, `by_chat`, `with_errors`, `successful`, `by_model`, `within_timeframe`
- Methods:
  - `response_time` - Calculate response time in ms
  - `success?` - Check if query was successful
  - `cost_estimate` - Estimate cost based on token usage (GPT-4o pricing)
  - `context_messages` - Fetch the actual Message records used as context
  - `summary` - Human-readable summary

### 3. QueryLoggerService ✅
**File:** `app/services/query_logger_service.rb`

A clean service interface with four main methods:
- `start_query(query_text:, telegram_user_id:, telegram_chat_id:, username:)` - Create initial log
- `add_search_context(log, results:, search_query:, context_text:)` - Add search metadata
- `complete_query(log, response_text:, model:, temperature:, max_tokens:, usage:)` - Finalize with response
- `log_error(log, error)` - Record errors

### 4. OpenAiService Updates ✅
**File:** `app/services/open_ai_service.rb`

Modified to return a hash with:
- `response` - The AI response text
- `usage` - Token usage (prompt_tokens, completion_tokens, total_tokens)
- `model`, `temperature`, `max_tokens` - Configuration metadata
- `error` - Error object if an exception occurred

### 5. TelegramBotService Integration ✅
**File:** `app/services/telegram_bot_service.rb`

Updated `process_user_query` method to:
- Start query logging at the beginning
- Log search context after search
- Log completion with token usage after AI response
- Log errors in the rescue block
- Handle both new hash format and legacy string format from OpenAI service

## Next Steps

### To Complete the Implementation:

Once rubygems is back online, run the migration:

```bash
cd /home/armfrancisco/COPbot
rvm use 3.3.6
bundle install  # if needed
bundle exec rails db:migrate
```

Or using the Makefile:
```bash
make db-setup
```

## Usage Examples

### Query Recent Logs
```ruby
# Get 10 most recent queries
UserQuery.recent.limit(10)

# Get queries from a specific user
UserQuery.by_user(123456).recent

# Get successful queries
UserQuery.successful.recent

# Get queries with errors
UserQuery.with_errors.recent
```

### Analyze Performance
```ruby
# Average response time
UserQuery.successful.average(:response_time_ms)

# Total cost estimate
UserQuery.successful.sum { |q| q.cost_estimate || 0 }

# Queries by model
UserQuery.by_model('gpt-4o').count
```

### Debug a Specific Query
```ruby
query = UserQuery.find(123)
query.query_text           # What did the user ask?
query.response_text        # What was the response?
query.context_messages     # Which messages were used as context?
query.context_provided     # The full context sent to OpenAI
query.search_results_count # How many results did the search return?
query.total_tokens         # How many tokens were used?
query.response_time        # How long did it take?
query.success?             # Was it successful?
```

## Benefits

✅ **Complete Audit Trail** - Every query and response is logged
✅ **Debugging Support** - See exactly what context was provided for any query
✅ **Cost Tracking** - Track token usage and estimate costs
✅ **Performance Monitoring** - Monitor response times and identify slow queries
✅ **Error Analysis** - Identify patterns in errors and failures
✅ **Message Traceability** - Know exactly which messages contributed to each response via `context_message_ids`
✅ **Clean API** - Easy to use in other parts of the application
✅ **Indefinite Retention** - All data is kept for historical analysis

## Architecture

The system follows a clean service-oriented architecture:

1. **TelegramBotService** receives the query and initiates logging
2. **QueryLoggerService** manages the lifecycle of query logs
3. **SearchService** finds relevant messages
4. **OpenAiService** generates the response with metadata
5. **UserQuery** model stores and provides access to the data

All components are loosely coupled and can be easily extended or modified.

