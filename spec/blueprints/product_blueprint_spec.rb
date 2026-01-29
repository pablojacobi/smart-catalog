# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductBlueprint do
  let(:category) { create(:category, name: 'Electronics') }
  let(:brand) { create(:brand, name: 'Apple') }
  let(:product) do
    create(:product,
           name: 'MacBook Pro',
           sku: 'MBP-001',
           price: 1999.99,
           currency: 'USD',
           in_stock: true,
           category: category,
           brand: brand,
           specifications: { 'memory' => '16GB' })
  end

  describe 'default view' do
    subject(:result) { described_class.render_as_hash(product) }

    it 'includes basic fields' do
      expect(result[:id]).to eq(product.id)
      expect(result[:name]).to eq('MacBook Pro')
      expect(result[:sku]).to eq('MBP-001')
      expect(result[:price]).to eq(1999.99)
      expect(result[:currency]).to eq('USD')
      expect(result[:in_stock]).to be true
    end

    it 'includes formatted_price' do
      expect(result[:formatted_price]).to eq('USD 1999.99')
    end

    it 'includes category association' do
      expect(result[:category][:name]).to eq('Electronics')
    end

    it 'includes brand association' do
      expect(result[:brand][:name]).to eq('Apple')
    end
  end

  describe 'normal view' do
    subject(:result) { described_class.render_as_hash(product, view: :normal) }

    it 'includes description and status' do
      expect(result).to have_key(:description)
      expect(result).to have_key(:status)
      expect(result).to have_key(:stock_quantity)
    end
  end

  describe 'extended view' do
    subject(:result) { described_class.render_as_hash(product, view: :extended) }

    it 'includes specifications' do
      expect(result[:specifications]).to eq({ 'memory' => '16GB' })
    end

    it 'includes timestamps' do
      expect(result[:created_at]).to be_present
      expect(result[:updated_at]).to be_present
    end
  end

  describe 'minimal view' do
    subject(:result) { described_class.render_as_hash(product, view: :minimal) }

    it 'excludes full associations' do
      expect(result).not_to have_key(:category)
      expect(result).not_to have_key(:brand)
    end

    it 'includes category_name and brand_name' do
      expect(result[:category_name]).to eq('Electronics')
      expect(result[:brand_name]).to eq('Apple')
    end
  end

  describe 'collection rendering' do
    let(:products) { create_list(:product, 3) }

    it 'renders array of products' do
      result = described_class.render_as_hash(products)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end
  end
end
