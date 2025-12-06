# Disable output buffering for Sidekiq
STDOUT.sync = true
STDERR.sync = true

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Log when Sidekiq starts
  config.on(:startup) do
    puts "=" * 80
    puts "Sidekiq worker started!"
    puts "Redis URL: #{ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')}"
    puts "=" * 80
    STDOUT.flush
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
