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
    puts "Bot will process channel messages and respond when mentioned/tagged"
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

        # Get bot info to detect mentions
        bot_info = bot.api.get_me
        bot_username = bot_info.username
        puts "Bot username: @#{bot_username}"
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
          puts "  Is bot: #{message.from&.is_bot || false}"
          puts "  Text: #{message.text || message.caption || '[No text]'}"
          puts "=" * 80

          # Skip messages from bots (including our own bot's responses)
          if message.from&.is_bot
            puts "⊗ Skipping message from bot"
            next
          end

          # Store messages from channels, groups, and supergroups (bot must be admin in channels)
          if ['channel', 'supergroup', 'group'].include?(message.chat.type)
            puts "✓ Storing message from #{message.chat.type}"
            TelegramBotService.process_channel_message(message)
          end

          # Handle messages in private chats, groups, and supergroups (not channels)
          if message.chat.type != 'channel' && message.text
            is_private_chat = message.chat.type == 'private'
            is_mentioned = false
            query = message.text

            # Check if bot is mentioned (via @username or reply)
            unless is_private_chat
              # Check for @mention in text
              if message.text.include?("@#{bot_username}")
                is_mentioned = true
                # Remove the @mention from the query
                query = message.text.gsub("@#{bot_username}", '').strip
              end

              # Check for @mention in entities
              if message.entities&.any? { |entity| entity.type == 'mention' || entity.type == 'text_mention' }
                # Get mentioned usernames from entities
                message.entities.each do |entity|
                  if entity.type == 'mention'
                    offset = entity.offset
                    length = entity.length
                    mentioned_text = message.text[offset, length]
                    if mentioned_text == "@#{bot_username}"
                      is_mentioned = true
                      query = message.text.gsub("@#{bot_username}", '').strip
                    end
                  end
                end
              end

              # Check if message is a reply to the bot
              if message.reply_to_message&.from&.username == bot_username
                is_mentioned = true
              end
            end

            # Respond if in private chat or if mentioned in group
            if is_private_chat || is_mentioned
              # Handle /start and /help commands
              if message.text == '/start'
                bot.api.send_message(
                  chat_id: message.chat.id,
                  text: "Welcome! I'm your AI concierge.\n\n" \
                        "💬 In private chats: Just send me your question directly\n" \
                        "👥 In groups: Tag me (@#{bot_username}) or reply to my messages to ask questions\n\n" \
                        "Example: @#{bot_username} How do I reset my password?\n\n" \
                        "I search through channel messages to help answer your questions.\n" \
                        "You can ask in English, Filipino, or Taglish!"
                )
              elsif message.text == '/help'
                bot.api.send_message(
                  chat_id: message.chat.id,
                  text: "How to use:\n" \
                        "💬 Private chat: Send your question directly\n" \
                        "👥 Groups: Tag me with @#{bot_username} or reply to my messages\n\n" \
                        "I search through channel messages to answer your questions."
                )
              else
                # Process the query
                query = query.strip
                unless query.empty?
                  puts "🤖 Processing query: #{query}"
                  TelegramBotService.process_user_query(bot, message, query)
                end
              end
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
