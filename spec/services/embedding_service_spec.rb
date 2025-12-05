require 'rails_helper'

RSpec.describe EmbeddingService, type: :service do
  describe '.embed' do
    context 'with valid text' do
      it 'returns an embedding array', :vcr do
        text = 'This is a test message'
        
        embedding = EmbeddingService.embed(text)
        
        expect(embedding).to be_an(Array)
        expect(embedding.length).to eq(1536)
        expect(embedding.first).to be_a(Float)
      end
    end

    context 'with blank text' do
      it 'returns nil' do
        expect(EmbeddingService.embed('')).to be_nil
        expect(EmbeddingService.embed(nil)).to be_nil
      end
    end

    context 'when OpenAI API fails' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_raise(StandardError.new('API Error'))
      end

      it 'logs error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Error generating embedding/)
        expect(EmbeddingService.embed('test')).to be_nil
      end
    end
  end
end

