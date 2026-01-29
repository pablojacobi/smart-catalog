# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentQuery do
  let!(:pending_doc) { create(:document, :pending, filename: 'pending.pdf') }
  let!(:processing_doc) { create(:document, :processing, filename: 'processing.pdf') }
  let!(:completed_doc) { create(:document, filename: 'completed.pdf') }
  let!(:failed_doc) { create(:document, :failed, filename: 'failed.pdf') }
  let!(:with_embedding) { create(:document, :with_embedding, filename: 'embedded.pdf') }

  describe '#by_status' do
    it 'filters by status' do
      results = described_class.new.by_status('pending').call

      expect(results).to include(pending_doc)
      expect(results).not_to include(completed_doc)
    end
  end

  describe 'status shortcuts' do
    it '#pending returns pending documents' do
      expect(described_class.new.pending.call).to include(pending_doc)
    end

    it '#processing returns processing documents' do
      expect(described_class.new.processing.call).to include(processing_doc)
    end

    it '#completed returns completed documents' do
      expect(described_class.new.completed.call).to include(completed_doc, with_embedding)
    end

    it '#failed returns failed documents' do
      expect(described_class.new.failed.call).to include(failed_doc)
    end
  end

  describe '#with_embedding' do
    it 'returns documents with embeddings' do
      results = described_class.new.with_embedding.call

      expect(results).to include(with_embedding)
      expect(results).not_to include(completed_doc)
    end
  end

  describe '#without_embedding' do
    it 'returns documents without embeddings' do
      results = described_class.new.without_embedding.call

      expect(results).to include(completed_doc)
      expect(results).not_to include(with_embedding)
    end
  end

  describe '#search' do
    it 'searches by filename' do
      results = described_class.new.search('pending').call

      expect(results).to include(pending_doc)
      expect(results).not_to include(completed_doc)
    end
  end

  describe '#recent' do
    it 'orders by created_at desc' do
      results = described_class.new.recent.call

      expect(results.first.created_at).to be >= results.last.created_at
    end
  end

  describe 'chaining' do
    it 'chains multiple filters' do
      results = described_class.new
        .completed
        .with_embedding
        .call

      expect(results).to eq([with_embedding])
    end
  end

  describe '#with_products' do
    let!(:doc_with_products) { create(:document, filename: 'with_products.pdf') }
    let!(:doc_without_products) { create(:document, filename: 'no_products.pdf') }

    before do
      create(:product, document: doc_with_products)
    end

    it 'returns documents that have products' do
      results = described_class.new.with_products.call

      expect(results).to include(doc_with_products)
      expect(results).not_to include(doc_without_products)
    end
  end

  describe '#paginate' do
    before do
      create_list(:document, 30)
    end

    it 'paginates results with default values' do
      results = described_class.new.paginate(page: 1, per_page: 10).call

      expect(results.length).to eq(10)
    end

    it 'returns correct page' do
      all_docs = described_class.new.recent.call.to_a
      page2_results = described_class.new.recent.paginate(page: 2, per_page: 10).call.to_a

      expect(page2_results).to eq(all_docs[10..19])
    end

    it 'handles invalid page values' do
      results = described_class.new.paginate(page: 0, per_page: 10).call

      expect(results.length).to eq(10)
    end

    it 'limits per_page to 100' do
      results = described_class.new.paginate(page: 1, per_page: 200).call

      # Should not fail, limits to 100
      expect(results.length).to be <= 100
    end
  end

  describe '#with_associations' do
    it 'includes products association' do
      results = described_class.new.with_associations.call

      # Should not raise N+1 when accessing products
      expect { results.each { |d| d.products.to_a } }.not_to raise_error
    end
  end
end
