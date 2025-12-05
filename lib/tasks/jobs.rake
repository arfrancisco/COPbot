namespace :jobs do
  desc 'Delete messages older than 90 days'
  task delete_old_messages: :environment do
    puts 'Starting DeleteOldMessagesJob...'
    
    deleted_count = DeleteOldMessagesJob.perform_now
    
    puts "Job completed: Deleted #{deleted_count} old messages"
  rescue StandardError => e
    puts "Error running DeleteOldMessagesJob: #{e.message}"
    exit 1
  end
end

