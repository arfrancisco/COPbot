require 'rails_helper'

RSpec.describe DeleteOldMessagesJob, type: :job do
  describe '#perform' do
    let!(:recent_message) { create(:message, message_timestamp: 30.days.ago) }
    let!(:old_message1) { create(:message, message_timestamp: 100.days.ago) }
    let!(:old_message2) { create(:message, message_timestamp: 120.days.ago) }

    it 'deletes messages older than 90 days' do
      expect {
        DeleteOldMessagesJob.perform_now
      }.to change(Message, :count).by(-2)

      expect(Message.exists?(recent_message.id)).to be true
      expect(Message.exists?(old_message1.id)).to be false
      expect(Message.exists?(old_message2.id)).to be false
    end

    it 'returns the count of deleted messages' do
      count = DeleteOldMessagesJob.perform_now
      expect(count).to eq(2)
    end

    it 'logs the deletion' do
      expect(Rails.logger).to receive(:info).with(/Deleted 2 messages/)
      DeleteOldMessagesJob.perform_now
    end
  end
end
