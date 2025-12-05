require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      message = build(:message)
      expect(message).to be_valid
    end

    it 'is invalid without channel_id' do
      message = build(:message, channel_id: nil)
      expect(message).not_to be_valid
    end

    it 'is invalid without text' do
      message = build(:message, text: nil)
      expect(message).not_to be_valid
    end

    it 'is invalid without message_timestamp' do
      message = build(:message, message_timestamp: nil)
      expect(message).not_to be_valid
    end

    it 'is invalid without embedding' do
      message = build(:message, embedding: nil)
      expect(message).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:recent_message) { create(:message, :recent) }
    let!(:old_message) { create(:message, :old) }

    describe '.recent' do
      it 'returns only messages from the last 90 days' do
        expect(Message.recent).to include(recent_message)
        expect(Message.recent).not_to include(old_message)
      end
    end

    describe '.by_channel' do
      let!(:channel1_message) { create(:message, channel_id: 12345) }
      let!(:channel2_message) { create(:message, channel_id: 67890) }

      it 'returns only messages from specified channel' do
        expect(Message.by_channel(12345)).to include(channel1_message)
        expect(Message.by_channel(12345)).not_to include(channel2_message)
      end
    end

    describe '.ordered' do
      it 'returns messages ordered by timestamp desc' do
        older = create(:message, message_timestamp: 2.days.ago)
        newer = create(:message, message_timestamp: 1.day.ago)
        
        expect(Message.ordered.first).to eq(newer)
        expect(Message.ordered.last).to eq(older)
      end
    end
  end

  describe '#old?' do
    it 'returns true for messages older than 90 days' do
      message = build(:message, :old)
      expect(message.old?).to be true
    end

    it 'returns false for recent messages' do
      message = build(:message, :recent)
      expect(message.old?).to be false
    end
  end

  describe '#age_in_days' do
    it 'returns the age of message in days' do
      message = create(:message, message_timestamp: 5.days.ago)
      expect(message.age_in_days).to eq(5)
    end
  end
end

