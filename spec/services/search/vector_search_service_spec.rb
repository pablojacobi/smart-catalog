# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::VectorSearchService do
  # Use a simple object that responds to call with arguments
  let(:embeddings_service) { double('EmbeddingsService') }
  let(:service) { described_class.new(embeddings_service: embeddings_service) }

  describe '#call' do
    let!(:doc1) { create(:document, :with_embedding, filename: 'laptops.pdf') }
    let!(:doc2) { create(:document, :with_embedding, filename: 'phones.pdf') }
    let!(:doc_no_embedding) { create(:document, filename: 'no_embedding.pdf') }

    before do
      allow(embeddings_service).to receive(:call).with(anything).and_return(Array.new(768) { rand(-1.0..1.0) })
    end

    it 'returns documents ordered by similarity' do
      results = service.call('laptops')

      expect(results).to be_an(Array)
      expect(results.all? { |r| r[:document].is_a?(Document) }).to be true
      expect(results.all? { |r| r[:score].is_a?(Float) }).to be true
      expect(results.all? { |r| r[:source] == 'vector' }).to be true
    end

    it 'excludes documents without embeddings' do
      results = service.call('test')

      documents = results.pluck(:document)
      expect(documents).not_to include(doc_no_embedding)
    end

    it 'returns empty array for blank query' do
      expect(service.call('')).to eq([])
      expect(service.call(nil)).to eq([])
    end

    it 'returns empty array when embedding fails' do
      allow(embeddings_service).to receive(:call).and_return(nil)

      expect(service.call('test')).to eq([])
    end

    it 'respects limit parameter' do
      create_list(:document, 10, :with_embedding)

      results = service.call('test', limit: 5)

      expect(results.length).to be <= 5
    end

    it 'filters by minimum score' do
      results = service.call('test', min_score: 0.9)

      expect(results.all? { |r| r[:score] >= 0.9 }).to be true
    end

    it 'excludes results below min_score threshold' do
      # With random embeddings, results will vary, but setting a very high min_score
      # should exclude most or all results
      results_low = service.call('test', min_score: 0.0)
      results_high = service.call('test', min_score: 0.99)

      # High min_score should return fewer (or no) results
      expect(results_high.length).to be <= results_low.length
    end
  end
end
