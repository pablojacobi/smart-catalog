# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product do
  describe 'validations' do
    subject { build(:product) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:sku).allow_nil }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_inclusion_of(:currency).in_array(%w[USD EUR GBP]).allow_nil }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to belong_to(:brand).optional }
  end

  describe 'scopes' do
    let!(:active_product) { create(:product, status: 'active') }
    let!(:inactive_product) { create(:product, :inactive) }
    let!(:in_stock_product) { create(:product, in_stock: true) }
    let!(:out_of_stock_product) { create(:product, :out_of_stock) }

    describe '.active' do
      it 'returns active products' do
        expect(described_class.active).to include(active_product)
        expect(described_class.active).not_to include(inactive_product)
      end
    end

    describe '.in_stock' do
      it 'returns in-stock products' do
        expect(described_class.in_stock).to include(in_stock_product)
        expect(described_class.in_stock).not_to include(out_of_stock_product)
      end
    end

    describe '.price_range' do
      it 'returns products within price range' do
        cheap = create(:product, price: 50)
        expensive = create(:product, price: 500)

        results = described_class.price_range(40, 100)
        expect(results).to include(cheap)
        expect(results).not_to include(expensive)
      end
    end

    describe '.by_category' do
      it 'returns products in specified category' do
        category = create(:category)
        product_in = create(:product, category: category)
        product_out = create(:product)

        expect(described_class.by_category(category.id)).to include(product_in)
        expect(described_class.by_category(category.id)).not_to include(product_out)
      end
    end

    describe '.search_by_name' do
      it 'returns products matching name query' do
        laptop = create(:product, name: 'MacBook Pro')
        phone = create(:product, name: 'iPhone')

        results = described_class.search_by_name('MacBook')
        expect(results).to include(laptop)
        expect(results).not_to include(phone)
      end

      it 'is case insensitive' do
        product = create(:product, name: 'MacBook Pro')
        expect(described_class.search_by_name('macbook')).to include(product)
      end
    end
  end

  describe '#formatted_price' do
    it 'returns formatted price with currency' do
      product = build(:product, price: 99.99, currency: 'USD')
      expect(product.formatted_price).to eq('USD 99.99')
    end

    it 'returns nil if price is nil' do
      product = build(:product, price: nil)
      expect(product.formatted_price).to be_nil
    end
  end

  describe '#specification' do
    it 'returns specification value by key' do
      product = build(:product, specifications: { 'color' => 'red', 'size' => 'large' })
      expect(product.specification(:color)).to eq('red')
      expect(product.specification('size')).to eq('large')
    end

    it 'returns nil for missing keys' do
      product = build(:product, specifications: {})
      expect(product.specification(:missing)).to be_nil
    end
  end

  describe '#embedding_text' do
    let(:category) { build(:category, name: 'Laptops') }
    let(:brand) { build(:brand, name: 'Apple') }

    it 'includes product name' do
      product = build(:product, name: 'MacBook Pro')
      expect(product.embedding_text).to include('MacBook Pro')
    end

    it 'includes brand name when present' do
      product = build(:product, name: 'MacBook Pro', brand: brand)
      expect(product.embedding_text).to include('by Apple')
    end

    it 'includes category name when present' do
      product = build(:product, name: 'MacBook Pro', category: category)
      expect(product.embedding_text).to include('in Laptops')
    end

    it 'includes description when present' do
      product = build(:product, name: 'MacBook Pro', description: 'A powerful laptop')
      expect(product.embedding_text).to include('A powerful laptop')
    end

    it 'includes specifications when present' do
      product = build(:product, name: 'MacBook Pro', specifications: { 'cpu' => 'M3', 'ram_gb' => 16 })
      text = product.embedding_text
      expect(text).to include('cpu: M3')
      expect(text).to include('ram_gb: 16')
    end

    it 'combines all parts with periods' do
      product = build(:product,
                      name: 'MacBook Pro',
                      brand: brand,
                      category: category,
                      description: 'Powerful laptop',
                      specifications: { 'cpu' => 'M3' })
      text = product.embedding_text
      expect(text).to include('MacBook Pro')
      expect(text).to include('by Apple')
      expect(text).to include('in Laptops')
      expect(text).to include('Powerful laptop')
      expect(text).to include('cpu: M3')
    end
  end
end
