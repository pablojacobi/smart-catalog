# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Chat E2E Integration', type: :integration do
  let(:sql_service) { Search::SqlSearchService.new }

  # Create test data
  let!(:laptops_category) { create(:category, name: 'Laptops', slug: 'laptops') }
  let!(:tablets_category) { create(:category, name: 'Tablets', slug: 'tablets') }
  let!(:accessories_category) { create(:category, name: 'Mobile Accessories', slug: 'mobile-accessories') }

  let!(:apple) { create(:brand, name: 'Apple', slug: 'apple') }
  let!(:samsung) { create(:brand, name: 'Samsung', slug: 'samsung') }
  let!(:dell) { create(:brand, name: 'Dell', slug: 'dell') }

  # Create products with various specs
  let!(:macbook_pro) do
    create(:product,
           name: 'MacBook Pro 14',
           category: laptops_category,
           brand: apple,
           price: 1999.00,
           specifications: { 'os' => 'macOS', 'ram_gb' => 32, 'gpu' => 'Apple M3' })
  end

  let!(:macbook_air) do
    create(:product,
           name: 'MacBook Air 13',
           category: laptops_category,
           brand: apple,
           price: 999.00,
           specifications: { 'os' => 'macOS', 'ram_gb' => 16, 'gpu' => 'Apple M2' })
  end

  let!(:dell_xps) do
    create(:product,
           name: 'Dell XPS 15',
           category: laptops_category,
           brand: dell,
           price: 1499.00,
           specifications: { 'os' => 'Windows 11', 'ram_gb' => 32, 'gpu' => 'NVIDIA RTX 4070' })
  end

  let!(:gaming_laptop) do
    create(:product,
           name: 'ASUS ROG Zephyrus',
           category: laptops_category,
           brand: create(:brand, name: 'ASUS ROG'),
           price: 1799.00,
           specifications: { 'os' => 'Windows 11', 'ram_gb' => 32, 'gpu' => 'NVIDIA RTX 4080' })
  end

  let!(:budget_laptop) do
    create(:product,
           name: 'Budget Laptop',
           category: laptops_category,
           brand: dell,
           price: 499.00,
           specifications: { 'os' => 'Windows 11', 'ram_gb' => 8 })
  end

  let!(:samsung_tablet) do
    create(:product,
           name: 'Samsung Galaxy Tab S9',
           category: tablets_category,
           brand: samsung,
           price: 799.00,
           specifications: { 'os' => 'Android', 'ram_gb' => 12 })
  end

  let!(:budget_tablet) do
    create(:product,
           name: 'Budget Tablet',
           category: tablets_category,
           brand: samsung,
           price: 299.00,
           specifications: { 'os' => 'Android', 'ram_gb' => 4 })
  end

  let!(:accessory) do
    create(:product,
           name: 'Wireless Charger',
           category: accessories_category,
           brand: samsung,
           price: 49.99,
           specifications: { 'type' => 'charger' })
  end

  # Helper to execute query through SQL service (which is deterministic)
  # This tests the filter logic without LLM dependencies
  def search_with_filters(filters)
    results = sql_service.call(filters, limit: 50)
    results.map { |r| r[:product] }
  end

  # Helper to test classifier with mocked Gemini response
  def classify_query(query, mock_response)
    stub_gemini_chat(mock_response.to_json)
    classifier = Chat::QueryClassifierService.new
    classifier.call(query)
  end

  describe 'Basic Listing Queries' do
    it 'returns laptops when filtering by laptops category' do
      products = search_with_filters({ category: 'laptops' })

      expect(products).not_to be_empty
      expect(products.map { |p| p.category.slug }).to all(eq('laptops'))
    end

    it 'returns tablets when filtering by tablets category' do
      products = search_with_filters({ category: 'tablets' })

      expect(products).not_to be_empty
      expect(products.map { |p| p.category.slug }).to all(eq('tablets'))
    end

    it 'returns accessories when filtering by mobile-accessories category' do
      products = search_with_filters({ category: 'mobile-accessories' })

      expect(products).not_to be_empty
      expect(products.map { |p| p.category.slug }).to all(eq('mobile-accessories'))
    end
  end

  describe 'Price Filter Queries' do
    it 'returns laptops under $1000' do
      products = search_with_filters({ category: 'laptops', max_price: 1000 })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.price).to be <= 1000
      end
    end

    it 'returns products in price range $500-$1500' do
      products = search_with_filters({ min_price: 500, max_price: 1500 })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.price).to be >= 500
        expect(product.price).to be <= 1500
      end
    end

    it 'returns cheap tablets under $500' do
      products = search_with_filters({ category: 'tablets', max_price: 500 })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.price).to be <= 500
        expect(product.category.slug).to eq('tablets')
      end
    end
  end

  describe 'Brand Filter Queries' do
    it 'returns Apple products' do
      products = search_with_filters({ brand: 'apple' })

      expect(products).not_to be_empty
      expect(products.map { |p| p.brand.slug }).to all(eq('apple'))
    end

    it 'returns Samsung tablets' do
      products = search_with_filters({ brand: 'samsung', category: 'tablets' })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.brand.slug).to eq('samsung')
        expect(product.category.slug).to eq('tablets')
      end
    end

    it 'returns Dell laptops' do
      products = search_with_filters({ brand: 'dell', category: 'laptops' })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.brand.slug).to eq('dell')
        expect(product.category.slug).to eq('laptops')
      end
    end
  end

  describe 'Specification Filter Queries' do
    it 'returns laptops with RTX 4070' do
      products = search_with_filters({ category: 'laptops', specifications: { 'gpu' => 'RTX 4070' } })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.specifications['gpu']).to include('RTX 4070')
      end
    end

    it 'returns products with 32GB RAM' do
      products = search_with_filters({ specifications: { 'RAM' => '32GB' } })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.specifications['ram_gb'].to_i).to eq(32)
      end
    end

    it 'returns macOS laptops' do
      products = search_with_filters({ category: 'laptops', specifications: { 'os' => 'macOS' } })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.specifications['os']).to eq('macOS')
      end
    end
  end

  describe 'Combined Filter Queries' do
    it 'returns Apple laptops under $2000' do
      products = search_with_filters({ brand: 'apple', category: 'laptops', max_price: 2000 })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.brand.slug).to eq('apple')
        expect(product.category.slug).to eq('laptops')
        expect(product.price).to be <= 2000
      end
    end

    it 'returns gaming laptops with RTX graphics' do
      products = search_with_filters({ category: 'laptops', specifications: { 'gpu' => 'RTX' } })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.category.slug).to eq('laptops')
        expect(product.specifications['gpu']).to include('RTX')
      end
    end
  end

  describe 'Count Queries' do
    it 'classifies "How many laptops do you have?" as count query' do
      classification = classify_query(
        'How many laptops do you have?',
        { query_type: 'count', filters: { category: 'laptops' }, search_query: '' }
      )
      expect(classification[:query_type]).to eq('count')
    end

    it 'classifies "Count Apple products" as count query' do
      classification = classify_query(
        'Count Apple products',
        { query_type: 'count', filters: { brand: 'apple' }, search_query: '' }
      )
      expect(classification[:query_type]).to eq('count')
    end
  end

  describe 'Conversational Queries' do
    it 'classifies "Hi" as conversational' do
      classification = classify_query(
        'Hi',
        { query_type: 'conversational', filters: {}, search_query: '' }
      )
      expect(classification[:query_type]).to eq('conversational')
    end

    it 'classifies "What can you help me with?" as conversational' do
      classification = classify_query(
        'What can you help me with?',
        { query_type: 'conversational', filters: {}, search_query: '' }
      )
      expect(classification[:query_type]).to eq('conversational')
    end
  end

  describe 'Spanish Language Queries - Category Mapping' do
    it 'maps "computadores" to laptops category' do
      # SqlSearchService should map computadores -> laptops
      products = search_with_filters({ category: 'computadores' })

      expect(products).not_to be_empty
      expect(products.map { |p| p.category.slug }).to all(eq('laptops'))
    end

    it 'maps "tabletas" to tablets category' do
      products = search_with_filters({ category: 'tabletas' })

      expect(products).not_to be_empty
      expect(products.map { |p| p.category.slug }).to all(eq('tablets'))
    end
  end

  describe 'Spanish Language Queries - Combined Filters' do
    it 'returns laptops with 16GB RAM using Spanish category' do
      products = search_with_filters({ category: 'computadores', specifications: { 'ram_gb' => '16' } })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.category.slug).to eq('laptops')
        expect(product.specifications['ram_gb'].to_i).to eq(16)
      end
    end

    it 'returns cheap Samsung tablets using Spanish category' do
      products = search_with_filters({ brand: 'samsung', category: 'tabletas', max_price: 500 })

      expect(products).not_to be_empty
      products.each do |product|
        expect(product.brand.slug).to eq('samsung')
        expect(product.category.slug).to eq('tablets')
        expect(product.price).to be <= 500
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
