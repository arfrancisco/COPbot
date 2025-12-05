source 'https://rubygems.org'

ruby '3.4.5'

# Rails framework
gem 'rails', '~> 7.0.8'

# Database
gem 'pg', '~> 1.1'
gem 'pgvector'

# Web server
gem 'puma', '~> 5.0'

# Telegram bot
gem 'telegram-bot-ruby'

# OpenAI
gem 'ruby-openai'

# Environment variables
gem 'dotenv-rails'

# Reduces boot times through caching
gem 'bootsnap', require: false

# Windows timezone data
gem 'tzinfo-data', platforms: %i[ mingw mswin x64_mingw jruby ]

group :development, :test do
  gem 'debug', platforms: %i[ mri mingw x64_mingw ]
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails'
  gem 'faker'
end

group :test do
  gem 'vcr'
  gem 'webmock'
end

group :development do
  # Add any development-specific gems here
end

