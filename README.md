# Telegram AI Concierge Bot

A production-ready Telegram bot with AI-powered semantic search using OpenAI embeddings and pgvector. Built with Ruby on Rails 7 API, optimized for Heroku deployment.

## Features

- **Channel Message Indexing**: Automatically stores and indexes messages from Telegram channels (bot must be admin)
- **Semantic Search**: Uses OpenAI embeddings (text-embedding-3-small) and pgvector for intelligent message retrieval
- **RAG-Powered Responses**: Leverages GPT-4o-mini with retrieval-augmented generation for accurate answers
- **Multilingual Support**: Responds in English, Filipino/Tagalog, or Taglish based on user's query language
- **90-Day Rolling Window**: Automatically removes messages older than 90 days to optimize performance
- **Heroku-Ready**: Includes Procfile, app.json, and complete deployment configuration

## Tech Stack

- **Ruby**: 3.4.5
- **Rails**: 7.0.8 (API-only)
- **Database**: PostgreSQL with pgvector extension
- **AI/ML**: OpenAI API (embeddings + chat completion)
- **Bot Framework**: telegram-bot-ruby
- **Testing**: RSpec, FactoryBot, VCR, WebMock
- **Deployment**: Heroku, Docker

## Prerequisites

- Ruby 3.4.5
- PostgreSQL 14+ with pgvector extension
- Telegram Bot Token (from [@BotFather](https://t.me/botfather))
- OpenAI API Key

## Quick Start

### 1. Local Development Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd telegram-bot

# Install dependencies
bundle install

# Set up environment variables
cp .env.example .env
# Edit .env and add your TELEGRAM_BOT_TOKEN and OPENAI_API_KEY

# Create and migrate database
bundle exec rake db:create db:migrate

# Start the bot
bundle exec rake bot:listen
```

### 2. Docker Development Setup

```bash
# Copy environment file
cp .env.example .env
# Edit .env with your tokens

# Build and start services
docker-compose up --build

# In another terminal, run migrations
docker-compose exec web bundle exec rake db:migrate

# The bot will start automatically
```

The bot will be listening on the `bot` service, and you can access the web API at `http://localhost:3000`.

## Environment Variables

Create a `.env` file with the following variables:

```env
# Required
TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
OPENAI_API_KEY=your_openai_api_key

# Database (auto-configured on Heroku)
DATABASE_URL=postgresql://localhost/telegram_bot_development

# Optional
RAILS_ENV=development
RAILS_MAX_THREADS=5
```

## Usage

### Setting Up Your Bot

1. **Create a Telegram Bot**:
   - Message [@BotFather](https://t.me/botfather) on Telegram
   - Use `/newbot` command and follow instructions
   - Save the bot token

2. **Add Bot to Channels**:
   - Add your bot to channels where you want to index messages
   - Make the bot an **administrator** of those channels
   - The bot will automatically index new messages

3. **Interact with the Bot**:
   - Send `/start` to get welcome message
   - Send `/help` to see available commands
   - Use `/ask <question>` to search and get AI-powered answers

### Example Queries

```
/ask How do I reset my password?
/ask Paano mag-login sa system?
/ask What are the office hours?
```

## Heroku Deployment

### Option 1: Deploy Button

Click the button below to deploy directly to Heroku:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

### Option 2: Manual Deployment

```bash
# Login to Heroku
heroku login

# Create a new Heroku app
heroku create your-app-name

# Add PostgreSQL with pgvector support
heroku addons:create heroku-postgresql:standard-0

# Enable pgvector extension
heroku pg:psql -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Add Heroku Scheduler for cleanup job
heroku addons:create scheduler:standard

# Set environment variables
heroku config:set TELEGRAM_BOT_TOKEN=your_token
heroku config:set OPENAI_API_KEY=your_key

# Deploy
git push heroku main

# Run migrations
heroku run rake db:migrate

# Scale dynos (web + bot)
heroku ps:scale web=1 bot=1

# Check logs
heroku logs --tail --ps bot
```

### Setting Up Heroku Scheduler

1. Open Heroku Scheduler:
   ```bash
   heroku addons:open scheduler
   ```

2. Add a new job:
   - **Command**: `rake jobs:delete_old_messages`
   - **Frequency**: Daily
   - **Time**: Choose off-peak hours (e.g., 3:00 AM)

### Heroku Cost Estimation

- **Basic Web Dyno**: $7/month
- **Basic Bot Dyno**: $7/month
- **Standard-0 Postgres**: $50/month (required for pgvector)
- **Scheduler**: $0 (up to 2 jobs)
- **Total**: ~$64/month

## Architecture

### Database Schema

**messages** table:
- `id`: Primary key
- `channel_id`: Telegram channel ID (indexed)
- `text`: Message content
- `message_timestamp`: When message was sent (indexed)
- `embedding`: Vector embedding (1536 dimensions, indexed with ivfflat)
- `created_at`, `updated_at`: Rails timestamps

### Services

- **EmbeddingService**: Generates OpenAI embeddings for text
- **SearchService**: Performs semantic search using vector similarity
- **TelegramBotService**: Handles message processing and user queries

### Background Jobs

- **DeleteOldMessagesJob**: Removes messages older than 90 days (run via Heroku Scheduler)

### Bot Flow

1. **Channel Messages**:
   - Bot receives message from channel → Extract text → Generate embedding → Store in DB

2. **User Queries**:
   - User sends `/ask <query>` → Generate query embedding → Search similar messages → Pass context to GPT-4o-mini → Return answer

## Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/message_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Development

### Running the Bot Locally

```bash
# Terminal 1: Start Rails console (optional, for debugging)
bundle exec rails console

# Terminal 2: Start the bot
bundle exec rake bot:listen
```

### Useful Commands

```bash
# Create database
bundle exec rake db:create

# Run migrations
bundle exec rake db:migrate

# Rollback migration
bundle exec rake db:rollback

# Reset database
bundle exec rake db:reset

# Run delete old messages job manually
bundle exec rake jobs:delete_old_messages

# Start Rails console
bundle exec rails console
```

## Troubleshooting

### Bot not receiving channel messages

- Ensure bot is added as **administrator** to the channel
- Check that channel privacy is set to **Public** or bot has proper permissions
- Verify `TELEGRAM_BOT_TOKEN` is correct

### OpenAI API errors

- Check `OPENAI_API_KEY` is valid and has credits
- Review rate limits: https://platform.openai.com/account/rate-limits
- Check OpenAI service status: https://status.openai.com/

### pgvector errors on Heroku

- Ensure you're using **Standard-0** or higher Postgres plan
- Verify extension is enabled: `heroku pg:psql -c "SELECT * FROM pg_extension WHERE extname = 'vector';"`
- If missing, create it: `heroku pg:psql -c "CREATE EXTENSION vector;"`

### Database connection issues

- Check `DATABASE_URL` environment variable
- Verify PostgreSQL is running: `pg_isready`
- Check database logs: `heroku logs --tail --ps postgres` (Heroku)

## Security Notes

- Never commit `.env` file or expose API keys
- Use environment variables for all sensitive data
- Regularly rotate API keys
- Monitor OpenAI usage to prevent unexpected costs
- Set up billing alerts on OpenAI platform

## Performance Optimization

- Messages are automatically deleted after 90 days (configurable)
- pgvector uses IVFFlat indexing for fast similarity search
- Consider upgrading to Heroku Performance dynos for high traffic
- Monitor database query performance with `heroku pg:diagnose`

## Customization

### Change retention period

Edit `app/jobs/delete_old_messages_job.rb`:
```ruby
cutoff_date = 30.days.ago  # Change from 90 to 30 days
```

### Modify search limit

Edit `app/services/telegram_bot_service.rb`:
```ruby
results = SearchService.search(query, limit: 30)  # Change from 25
```

### Change OpenAI model

Edit `app/services/open_ai_service.rb`:
```ruby
model: 'gpt-4o-mini'  # Or use gpt-4o for better quality (higher cost)
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - feel free to use this for your projects!

## Support

For issues and questions:
- Create an issue in the repository
- Check existing issues for solutions
- Review [documentation](docs/README.md) for detailed guides
- Review Telegram Bot API docs: https://core.telegram.org/bots/api
- Review OpenAI API docs: https://platform.openai.com/docs

## Documentation

Comprehensive documentation is available in the [docs/](docs/) folder:

- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - Quick 10-minute setup guide
- **[docs/TELEGRAM_GROUP_SETUP.md](docs/TELEGRAM_GROUP_SETUP.md)** - How to set up the bot in groups
- **[docs/HEROKU_DEPLOY.md](docs/HEROKU_DEPLOY.md)** - Heroku deployment guide
- **[docs/DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md)** - Pre-deployment checklist
- **[docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)** - Technical overview
- **[docs/QUERY_LOGGING_IMPLEMENTATION.md](docs/QUERY_LOGGING_IMPLEMENTATION.md)** - Query logging system
- **[docs/CHANGELOG.md](docs/CHANGELOG.md)** - Version history
- **[docs/STATUS.md](docs/STATUS.md)** - Project completion status

See [docs/README.md](docs/README.md) for the complete documentation index.

## Roadmap

- [ ] Add webhook support (instead of polling)
- [ ] Implement Sidekiq for background jobs
- [ ] Add admin dashboard
- [ ] Support multiple channels with different contexts
- [ ] Add conversation memory
- [ ] Implement user analytics
- [ ] Add message categories/tags
- [ ] Support for images and documents

---

Built with ❤️ using Ruby on Rails and OpenAI

