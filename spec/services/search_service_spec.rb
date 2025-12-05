require 'rails_helper'

RSpec.describe SearchService, type: :service do
  describe '.search' do
    let!(:message1) { create(:message, text: 'How to reset password', message_timestamp: 10.days.ago) }
    let!(:message2) { create(:message, text: 'Login instructions', message_timestamp: 5.days.ago) }

    context 'with valid query' do
      it 'returns relevant messages' do
        allow(EmbeddingService).to receive(:embed).and_return(Array.new(1536) { rand })

        results = SearchService.search('password reset', limit: 5)

        expect(results).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with blank query' do
      it 'returns empty relation' do
        results = SearchService.search('')
        expect(results).to be_empty
      end
    end

    context 'when embedding service fails' do
      before do
        allow(EmbeddingService).to receive(:embed).and_return(nil)
      end

      it 'returns empty relation' do
        results = SearchService.search('test query')
        expect(results).to be_empty
      end
    end
  end
end
