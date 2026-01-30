# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::SqlSearchService do
  let(:service) { described_class.new }

  describe '#call' do
    let!(:electronics) { create(:category, name: 'Electronics', slug: 'electronics') }
    let!(:clothing) { create(:category, name: 'Clothing', slug: 'clothing') }
    let!(:apple) { create(:brand, name: 'Apple', slug: 'apple') }
    let!(:samsung) { create(:brand, name: 'Samsung', slug: 'samsung') }

    let!(:macbook) { create(:product, name: 'MacBook', category: electronics, brand: apple, price: 1999) }
    let!(:iphone) { create(:product, name: 'iPhone', category: electronics, brand: apple, price: 999) }
    let!(:galaxy) { create(:product, name: 'Galaxy', category: electronics, brand: samsung, price: 899) }
    let!(:shirt) { create(:product, name: 'T-Shirt', category: clothing, price: 29) }

    it 'filters by category' do
      results = service.call({ category: 'electronics' })

      products = results.map { |r| r[:product] }
      expect(products).to include(macbook, iphone, galaxy)
      expect(products).not_to include(shirt)
    end

    it 'filters by brand' do
      results = service.call({ brand: 'apple' })

      products = results.map { |r| r[:product] }
      expect(products).to include(macbook, iphone)
      expect(products).not_to include(galaxy, shirt)
    end

    it 'filters by price range' do
      results = service.call({ min_price: 500, max_price: 1000 })

      products = results.map { |r| r[:product] }
      expect(products).to include(iphone, galaxy)
      expect(products).not_to include(macbook, shirt)
    end

    it 'filters by text query' do
      results = service.call({ query: 'MacBook' })

      products = results.map { |r| r[:product] }
      expect(products).to include(macbook)
      expect(products).not_to include(iphone, galaxy, shirt)
    end

    it 'combines multiple filters' do
      results = service.call({ category: 'electronics', brand: 'apple', max_price: 1000 })

      products = results.map { |r| r[:product] }
      expect(products).to include(iphone)
      expect(products).not_to include(macbook, galaxy, shirt)
    end

    it 'respects limit' do
      results = service.call({}, limit: 2)
      expect(results.length).to eq(2)
    end

    context 'with in_stock filter' do
      let!(:in_stock_product) { create(:product, name: 'In Stock', in_stock: true) }
      let!(:out_of_stock_product) { create(:product, name: 'Out of Stock', in_stock: false) }

      it 'filters for in-stock products when in_stock is true' do
        results = service.call({ in_stock: true })

        product_names = results.map { |r| r[:product].name }
        expect(product_names).to include('In Stock')
        expect(product_names).not_to include('Out of Stock')
      end

      it 'filters for out-of-stock products when in_stock is false' do
        results = service.call({ in_stock: false })

        product_names = results.map { |r| r[:product].name }
        expect(product_names).to include('Out of Stock')
        expect(product_names).not_to include('In Stock')
      end

      it 'returns all products when in_stock is nil' do
        results = service.call({ in_stock: nil })

        product_names = results.map { |r| r[:product].name }
        expect(product_names).to include('In Stock', 'Out of Stock')
      end
    end

    context 'with specification filters' do
      let!(:product_with_specs) do
        create(:product, name: 'Laptop', specifications: { 'RAM' => '16GB', 'Storage' => '512GB' })
      end
      let!(:product_different_specs) do
        create(:product, name: 'Other Laptop', specifications: { 'RAM' => '8GB', 'Storage' => '256GB' })
      end

      it 'filters by specification key-value pair' do
        results = service.call({ specifications: { 'RAM' => '16GB' } })

        product_names = results.map { |r| r[:product].name }
        expect(product_names).to include('Laptop')
        expect(product_names).not_to include('Other Laptop')
      end

      it 'filters by multiple specifications' do
        results = service.call({ specifications: { 'RAM' => '16GB', 'Storage' => '512GB' } })

        product_names = results.map { |r| r[:product].name }
        expect(product_names).to include('Laptop')
      end

      it 'ignores blank specifications' do
        results = service.call({ specifications: {} })

        # Should return all active products
        expect(results.length).to be > 0
      end
    end
  end

  describe '#count' do
    let!(:category) { create(:category, name: 'Electronics') }
    let!(:brand) { create(:brand, name: 'Apple') }

    before do
      create_list(:product, 5, category: category, brand: brand)
      create_list(:product, 3, category: category)
      create_list(:product, 2, :out_of_stock, category: category)
    end

    it 'returns count statistics' do
      counts = service.count({})

      expect(counts[:total]).to eq(10)
      expect(counts[:in_stock]).to eq(8)
      expect(counts[:by_category]).to eq({ 'Electronics' => 10 })
    end
  end
end
