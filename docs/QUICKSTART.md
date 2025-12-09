# Quick Start Guide

This guide will get your Telegram AI Concierge Bot up and running in under 10 minutes.

## Step 1: Get Your API Keys (5 minutes)

### Telegram Bot Token

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow the prompts to choose a name and username for your bot
4. Copy the bot token (looks like `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

### OpenAI API Key

1. Go to https://platform.openai.com/
2. Sign up or log in
3. Navigate to API Keys section
4. Click "Create new secret key"
5. Copy the key (starts with `sk-`)
6. Add a payment method if you haven't already

## Step 2: Setup the Application (3 minutes)

```bash
# Run the automated setup script
./bin/setup.sh

# Or manually:
bundle install
cp .env.example .env
# Edit .env with your API keys
bundle exec rake db:create db:migrate
```

## Step 3: Configure Your Bot (2 minutes)

1. Edit the `.env` file:
   ```env
   TELEGRAM_BOT_TOKEN=your_actual_token_here
   OPENAI_API_KEY=your_actual_key_here
   ```

2. Add your bot to a Telegram channel:
   - Go to your channel settings
   - Add administrators
   - Search for your bot by username
   - Add it as an administrator
   - Give it permission to read messages

## Step 4: Start the Bot

```bash
# Start the bot listener
bundle exec rake bot:listen
```

You should see:
```
Starting Telegram bot listener...
Bot connected successfully!
```

## Step 5: Test It Out!

1. In your channel, post a message
2. Open a private chat with your bot
3. Send your question directly (no `/ask` needed in private chat)
4. The bot should respond with information from your channel!

## Example Conversation

```
You: /start
Bot: Welcome! I'm your AI concierge...

You: How do I reset my password?
Bot: Based on the channel messages, you can reset your password by...

You: Paano mag-login?
Bot: Base sa mga mensahe, maaari kang mag-login sa pamamagitan ng...
```

## Troubleshooting

### Bot not responding?

- Check that `TELEGRAM_BOT_TOKEN` is correct in `.env`
- Make sure the bot is running (`bundle exec rake bot:listen`)
- Verify bot has admin access to the channel

### No search results?

- Wait a few minutes for channel messages to be indexed
- Check that messages have been posted in the channel
- Verify `OPENAI_API_KEY` is valid and has credits

### Database errors?

- Make sure PostgreSQL is running: `pg_isready`
- Check that pgvector extension is installed
- Try: `bundle exec rake db:reset`

## Docker Quick Start

If you prefer Docker:

```bash
# Edit .env with your API keys
cp .env.example .env

# Start everything
docker-compose up --build

# In another terminal, run migrations
docker-compose exec web bundle exec rake db:migrate
```

## Next Steps

- Review the full [../README.md](../README.md) for advanced configuration
- Set up Heroku deployment for production use (see [HEROKU_DEPLOY.md](./HEROKU_DEPLOY.md))
- Customize the bot responses in `app/services/open_ai_service.rb`
- Add more channels to index

## Getting Help

- Check [README.md](./README.md) for documentation index
- Review [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) for production deployment
- See [../README.md](../README.md) for troubleshooting
- Open an issue if you encounter problems

---

**Total Time: ~10 minutes**

Happy bot building! 🤖

