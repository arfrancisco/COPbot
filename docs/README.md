# COPbot Documentation

Welcome to the COPbot documentation! This folder contains all the documentation for the Telegram AI Concierge Bot.

## 📚 Documentation Index

### Getting Started
- **[QUICKSTART.md](./QUICKSTART.md)** - Quick 10-minute setup guide
- **[../README.md](../README.md)** - Main project overview and features
- **[TELEGRAM_GROUP_SETUP.md](./TELEGRAM_GROUP_SETUP.md)** - How to set up the bot in Telegram groups

### Deployment
- **[DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)** - Pre-deployment checklist
- **[HEROKU_DEPLOY.md](./HEROKU_DEPLOY.md)** - Heroku deployment guide

### Technical Documentation
- **[PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md)** - Technical overview and architecture
- **[CHANGELOG.md](./CHANGELOG.md)** - Version history and changes
- **[STATUS.md](./STATUS.md)** - Project completion status
- **[QUERY_LOGGING_IMPLEMENTATION.md](./QUERY_LOGGING_IMPLEMENTATION.md)** - Query logging system details

## 📖 Currently Implemented Features

### 1. Telegram Bot Integration
- Listens for channel/group messages
- Responds to user queries in private chats and groups (when mentioned)
- Commands: `/start`, `/help`

### 2. Message Indexing
- Automatically stores messages from channels/groups where bot is admin
- Generates OpenAI embeddings for semantic search
- Uses pgvector with HNSW indexing for fast similarity search

### 3. Semantic Search & RAG
- Vector similarity search using cosine distance
- Hybrid search combining semantic and keyword matching
- Retrieval-augmented generation using GPT-4o
- Multilingual support (English, Filipino, Taglish)

### 4. Query Logging
- Complete audit trail of all user queries
- Token usage tracking
- Performance metrics
- Error logging

### 5. Sender Tracking
- Stores sender information with messages (ID, name, username)
- Can reference who said what in responses

### 6. Background Jobs
- Automatic deletion of messages older than 90 days
- Immediate message processing on receipt

## 🚀 Available Commands

### Rake Tasks

```bash
# Start the bot listener
bundle exec rake bot:listen

# Delete old messages (90+ days)
bundle exec rake jobs:delete_old_messages
```

### Telegram Bot Commands

```
/start - Welcome message and instructions
/help - Display available commands
```

### User Interaction

- **Private Chat**: Send questions directly to the bot
- **Group Chat**: Mention the bot with `@botname` or reply to its messages

## 🔧 How It Works

1. **Message Collection**: Bot listens to channels/groups where it's an admin
2. **Embedding Generation**: Each message is converted to a 1536-dimensional vector using OpenAI
3. **Storage**: Messages stored in PostgreSQL with pgvector extension
4. **Search**: User queries are embedded and matched against stored messages using cosine similarity
5. **Response Generation**: Top relevant messages are used as context for GPT-4o to generate responses
6. **Logging**: All queries, responses, and metadata are logged to `user_queries` table

## 📊 Database Schema

### `messages` table
- `id` - Primary key
- `channel_id` - Telegram channel/group ID (string, supports composite IDs)
- `channel_name` - Channel/group name
- `text` - Message content
- `message_timestamp` - When message was sent
- `embedding` - JSONB embedding (legacy, kept for backup)
- `embedding_vector` - pgvector embedding (1536 dimensions, HNSW indexed)
- `sender_id` - Telegram user ID of sender
- `sender_name` - Full name of sender
- `sender_username` - Telegram username of sender

### `user_queries` table
- `id` - Primary key
- `telegram_user_id` - User who made the query
- `telegram_chat_id` - Chat where query was made
- `username` - Username of querier
- `query_text` - The question asked
- `response_text` - Bot's response
- `error_message` - Error if query failed
- `search_results_count` - Number of relevant messages found
- `context_message_ids` - IDs of messages used as context
- `context_provided` - Full context sent to OpenAI
- `search_query_used` - Query used for search
- `model_used` - OpenAI model (default: gpt-4o)
- `temperature`, `max_tokens` - OpenAI parameters
- `prompt_tokens`, `completion_tokens`, `total_tokens` - Token usage
- `queried_at`, `responded_at` - Timestamps
- `response_time_ms` - Response time in milliseconds

## 🛠️ Services

### EmbeddingService
Generates OpenAI embeddings for text using `text-embedding-3-small` model.

### SearchService
Performs semantic search using pgvector similarity search with hybrid keyword matching.

### TelegramBotService
Main bot service that:
- Processes channel messages
- Handles user queries
- Manages bot interactions

### OpenAiService
Generates responses using GPT-4o with provided context.

### QueryLoggerService
Logs all queries, responses, and metadata for analysis and debugging.

## 💡 Tips

1. **Bot must be admin** in channels/groups to see messages
2. **Privacy mode must be off** for groups (set via @BotFather)
3. **OpenAI quota** - Monitor your OpenAI usage to avoid unexpected costs
4. **Database size** - Old messages are automatically deleted after 90 days
5. **Response quality** - More indexed messages = better responses

## 🐛 Troubleshooting

See the main [README.md](../README.md) for troubleshooting guides.

## 📝 Contributing

When updating documentation:
1. Keep this README.md index up to date
2. Update the CHANGELOG.md for significant changes
3. Test that all internal links work

## 📧 Support

For issues and questions:
- Check the documentation files
- Review existing issues on GitHub
- See Telegram Bot API docs: https://core.telegram.org/bots/api
- See OpenAI API docs: https://platform.openai.com/docs

---

**Last Updated**: December 9, 2025  
**Documentation Status**: ✅ Accurate and up-to-date
