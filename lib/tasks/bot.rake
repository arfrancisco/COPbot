require 'telegram/bot'

namespace :bot do
  desc 'Start the Telegram bot listener'
  task listen: :environment do
    # Disable output buffering so logs show immediately
    STDOUT.sync = true
    STDERR.sync = true

    token = ENV['TELEGRAM_BOT_TOKEN']

    if token.blank?
      puts 'ERROR: TELEGRAM_BOT_TOKEN environment variable is not set'
      exit 1
    end

    puts "Starting Telegram bot listener..."
    puts "Bot will process channel messages and respond to /ask commands"
    puts "Press Ctrl+C to stop"

    # Handle graceful shutdown
    trap('INT') do
      puts "\nShutting down bot gracefully..."
      exit
    end

    trap('TERM') do
      puts "\nReceived TERM signal, shutting down..."
      exit
    end

    begin
      Telegram::Bot::Client.run(token) do |bot|
        puts "Bot connected successfully!"
        STDOUT.flush

        bot.listen do |message|
          next unless message.is_a?(Telegram::Bot::Types::Message)

          # Debug logging
          puts "=" * 80
          puts "Received message:"
          puts "  Chat type: #{message.chat.type}"
          puts "  Chat ID: #{message.chat.id}"
          puts "  Chat title: #{message.chat.title || 'N/A'}"
          puts "  From: #{message.from&.username || message.from&.first_name || 'Unknown'}"
          puts "  Text: #{message.text || message.caption || '[No text]'}"
          puts "=" * 80

          # Store messages from channels, groups, and supergroups (bot must be admin in channels)
          if ['channel', 'supergroup', 'group'].include?(message.chat.type)
            puts "✓ Storing message from #{message.chat.type}"
            TelegramBotService.process_channel_message(message)
          end

          # Handle commands in private chats, groups, and supergroups (not channels)
          if message.chat.type != 'channel' && message.text
            # Handle /ask command
            if message.text.start_with?('/ask')
              query = message.text.sub('/ask', '').strip

              if query.blank?
                bot.api.send_message(
                  chat_id: message.chat.id,
                  text: "Please provide a question. Usage: /ask your question here"
                )
                next
              end

              TelegramBotService.process_user_query(bot, message, query)
            elsif message.text == '/start'
              bot.api.send_message(
                chat_id: message.chat.id,
                text: "Welcome! I'm your AI concierge. Use /ask followed by your question to search for information.\n\n" \
                      "Example: /ask How do I reset my password?\n\n" \
                      "You can ask questions in English, Filipino, or Taglish!"
              )
            elsif message.text == '/help'
              bot.api.send_message(
                chat_id: message.chat.id,
                text: "Commands:\n" \
                      "/ask <question> - Ask me anything based on channel messages\n" \
                      "/help - Show this help message\n\n" \
                      "I search through the last 90 days of channel messages to help answer your questions."
              )
            end
          end
        rescue StandardError => e
          Rails.logger.error("Error processing message: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
    rescue Telegram::Bot::Exceptions::ResponseError => e
      puts "Telegram API error: #{e.message}"
      puts "Retrying in 5 seconds..."
      sleep 5
      retry
    rescue StandardError => e
      puts "Fatal error: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
end
