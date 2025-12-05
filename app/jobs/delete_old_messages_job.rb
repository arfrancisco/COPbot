class DeleteOldMessagesJob < ApplicationJob
  queue_as :default

  def perform
    cutoff_date = 90.days.ago

    deleted_count = Message.where('message_timestamp < ?', cutoff_date).delete_all

    Rails.logger.info("DeleteOldMessagesJob completed: Deleted #{deleted_count} messages older than #{cutoff_date}")

    deleted_count
  rescue StandardError => e
    Rails.logger.error("Error in DeleteOldMessagesJob: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
