# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Document do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:products).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:pending_doc) { create(:document, :pending) }
    let!(:processing_doc) { create(:document, :processing) }
    let!(:completed_doc) { create(:document) }
    let!(:failed_doc) { create(:document, :failed) }

    describe '.pending' do
      it 'returns pending documents' do
        expect(described_class.pending).to contain_exactly(pending_doc)
      end
    end

    describe '.processing' do
      it 'returns processing documents' do
        expect(described_class.processing).to contain_exactly(processing_doc)
      end
    end

    describe '.completed' do
      it 'returns completed documents' do
        expect(described_class.completed).to contain_exactly(completed_doc)
      end
    end

    describe '.failed' do
      it 'returns failed documents' do
        expect(described_class.failed).to contain_exactly(failed_doc)
      end
    end

    describe '.with_embedding' do
      it 'returns documents with embeddings' do
        doc_with = create(:document, :with_embedding)
        doc_without = create(:document)

        expect(described_class.with_embedding).to include(doc_with)
        expect(described_class.with_embedding).not_to include(doc_without)
      end
    end
  end

  describe '#processed?' do
    it 'returns true for completed documents' do
      document = build(:document, status: 'completed')
      expect(document.processed?).to be true
    end

    it 'returns false for non-completed documents' do
      document = build(:document, status: 'pending')
      expect(document.processed?).to be false
    end
  end

  describe '#processing!' do
    it 'updates status to processing' do
      document = create(:document, :pending)
      document.processing!
      expect(document.reload.status).to eq('processing')
    end
  end

  describe '#complete!' do
    it 'updates status to completed and sets processed_at' do
      document = create(:document, :processing)

      freeze_time do
        document.complete!
        expect(document.status).to eq('completed')
        expect(document.processed_at).to eq(Time.current)
      end
    end
  end

  describe '#fail!' do
    it 'updates status to failed and stores error message' do
      document = create(:document, :processing)
      document.fail!('Something went wrong')

      expect(document.status).to eq('failed')
      expect(document.metadata['error']).to eq('Something went wrong')
    end
  end
end
