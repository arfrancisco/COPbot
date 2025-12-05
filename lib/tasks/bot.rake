namespace :bot do
  desc 'Start the Telegram bot listener'
  task listen: :environment do
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

        bot.listen do |message|
          next unless message.is_a?(Telegram::Bot::Types::Message)

          # Process channel messages (bot must be admin)
          if message.chat.type == 'channel'
            TelegramBotService.process_channel_message(message)
          else
            # Process user queries in private chats or groups
            next unless message.text

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

