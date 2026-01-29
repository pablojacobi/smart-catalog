# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentBlueprint do
  let(:document) do
    create(:document,
           filename: 'catalog.pdf',
           content_type: 'application/pdf',
           status: 'completed',
           content_length: 1024,
           summary: 'Product catalog',
           metadata: { pages: 10 },
           content: 'Full document content')
  end

  describe 'default view' do
    subject(:result) { described_class.render_as_hash(document) }

    it 'includes basic fields' do
      expect(result[:id]).to eq(document.id)
      expect(result[:filename]).to eq('catalog.pdf')
      expect(result[:content_type]).to eq('application/pdf')
      expect(result[:status]).to eq('completed')
      expect(result[:content_length]).to eq(1024)
    end

    it 'includes products_count' do
      create_list(:product, 3, document: document)
      result = described_class.render_as_hash(document)

      expect(result[:products_count]).to eq(3)
    end

    it 'includes formatted processed_at' do
      document.update!(processed_at: Time.current)
      result = described_class.render_as_hash(document)

      expect(result[:processed_at]).to be_present
    end

    it 'includes formatted created_at' do
      expect(result[:created_at]).to be_present
    end
  end

  describe 'normal view' do
    subject(:result) { described_class.render_as_hash(document, view: :normal) }

    it 'includes summary' do
      expect(result[:summary]).to eq('Product catalog')
    end
  end

  describe 'extended view' do
    subject(:result) { described_class.render_as_hash(document, view: :extended) }

    before do
      create_list(:product, 2, document: document)
    end

    it 'includes normal view fields' do
      expect(result[:summary]).to eq('Product catalog')
    end

    it 'includes metadata' do
      expect(result[:metadata]).to eq({ 'pages' => 10 })
    end

    it 'includes associated products' do
      expect(result[:products]).to be_an(Array)
      expect(result[:products].length).to eq(2)
    end

    it 'limits products to 20' do
      create_list(:product, 25, document: document)
      result = described_class.render_as_hash(document, view: :extended)

      expect(result[:products].length).to eq(20)
    end
  end

  describe 'with_content view' do
    subject(:result) { described_class.render_as_hash(document, view: :with_content) }

    it 'includes extended view fields' do
      expect(result[:summary]).to be_present
      expect(result[:metadata]).to be_present
    end

    it 'includes content' do
      expect(result[:content]).to eq('Full document content')
    end
  end

  describe 'collection rendering' do
    let(:documents) { create_list(:document, 3) }

    it 'renders array of documents' do
      result = described_class.render_as_hash(documents)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end
  end
end
