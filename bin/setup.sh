#!/usr/bin/env bash
set -e

echo "=== Telegram AI Concierge Bot - Setup Script ==="
echo ""

# Check Ruby version
echo "Checking Ruby version..."
ruby_version=$(ruby -v | cut -d ' ' -f2 | cut -d 'p' -f1)
echo "Ruby version: $ruby_version"

# Check if .env exists
if [ ! -f .env ]; then
  echo ""
  echo "Creating .env file from template..."
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "✓ .env file created. Please edit it with your API keys."
  else
    echo "✗ .env.example not found!"
    exit 1
  fi
else
  echo "✓ .env file already exists"
fi

# Install dependencies
echo ""
echo "Installing dependencies..."
bundle check > /dev/null 2>&1 || bundle install

# Check if PostgreSQL is running
echo ""
echo "Checking PostgreSQL..."
if command -v pg_isready > /dev/null 2>&1; then
  if pg_isready > /dev/null 2>&1; then
    echo "✓ PostgreSQL is running"
  else
    echo "✗ PostgreSQL is not running. Please start PostgreSQL."
    exit 1
  fi
else
  echo "⚠ pg_isready not found. Assuming PostgreSQL is configured via DATABASE_URL"
fi

# Setup database
echo ""
echo "Setting up database..."
bundle exec rake db:create 2>/dev/null || echo "Database already exists"
bundle exec rake db:migrate
echo "✓ Database setup complete"

# Check environment variables
echo ""
echo "Checking environment variables..."
source .env 2>/dev/null || true

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ "$TELEGRAM_BOT_TOKEN" = "your_telegram_bot_token_here" ]; then
  echo "⚠ TELEGRAM_BOT_TOKEN not set in .env"
  echo "  Get your token from @BotFather on Telegram"
else
  echo "✓ TELEGRAM_BOT_TOKEN is set"
fi

if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
  echo "⚠ OPENAI_API_KEY not set in .env"
  echo "  Get your key from https://platform.openai.com/api-keys"
else
  echo "✓ OPENAI_API_KEY is set"
fi

# Run tests
echo ""
read -p "Do you want to run tests? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Running tests..."
  RAILS_ENV=test bundle exec rake db:migrate
  bundle exec rspec
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Edit .env file with your API keys if you haven't already"
echo "2. Make sure your bot is added as admin to your Telegram channels"
echo "3. Start the bot: bundle exec rake bot:listen"
echo ""
echo "Useful commands:"
echo "  bundle exec rails console     - Open Rails console"
echo "  bundle exec rake bot:listen   - Start the bot"
echo "  bundle exec rspec             - Run tests"
echo "  docker-compose up             - Run with Docker"
echo ""

