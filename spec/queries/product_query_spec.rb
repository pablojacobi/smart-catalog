# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductQuery do
  let!(:electronics) { create(:category, name: 'Electronics', slug: 'electronics') }
  let!(:clothing) { create(:category, name: 'Clothing', slug: 'clothing') }
  let!(:apple) { create(:brand, name: 'Apple', slug: 'apple') }
  let!(:samsung) { create(:brand, name: 'Samsung', slug: 'samsung') }

  let!(:macbook) { create(:product, name: 'MacBook Pro', category: electronics, brand: apple, price: 1999, status: 'active') }
  let!(:iphone) { create(:product, name: 'iPhone', category: electronics, brand: apple, price: 999, status: 'active') }
  let!(:galaxy) { create(:product, name: 'Galaxy', category: electronics, brand: samsung, price: 899, status: 'active', in_stock: false) }
  let!(:shirt) { create(:product, name: 'T-Shirt', category: clothing, price: 29, status: 'inactive') }

  describe '#active' do
    it 'returns only active products' do
      results = described_class.new.active.call

      expect(results).to include(macbook, iphone, galaxy)
      expect(results).not_to include(shirt)
    end
  end

  describe '#by_status' do
    it 'filters by status' do
      results = described_class.new.by_status('inactive').call

      expect(results).to include(shirt)
      expect(results).not_to include(macbook, iphone, galaxy)
    end

    it 'returns all when status is blank' do
      results = described_class.new.by_status('').call

      expect(results.count).to eq(4)
    end

    it 'returns all when status is nil' do
      results = described_class.new.by_status(nil).call

      expect(results.count).to eq(4)
    end
  end

  describe '#by_category' do
    it 'filters by category slug' do
      results = described_class.new.by_category('electronics').call

      expect(results).to include(macbook, iphone, galaxy)
      expect(results).not_to include(shirt)
    end

    it 'filters by category name (case insensitive)' do
      results = described_class.new.by_category('Electronics').call

      expect(results).to include(macbook)
    end

    it 'returns none for non-existent category' do
      results = described_class.new.by_category('nonexistent').call

      expect(results).to be_empty
    end
  end

  describe '#by_brand' do
    it 'filters by brand slug' do
      results = described_class.new.by_brand('apple').call

      expect(results).to include(macbook, iphone)
      expect(results).not_to include(galaxy)
    end
  end

  describe '#price_range' do
    it 'filters by minimum price' do
      results = described_class.new.price_range(1000, nil).call

      expect(results).to include(macbook)
      expect(results).not_to include(iphone, galaxy)
    end

    it 'filters by maximum price' do
      results = described_class.new.price_range(nil, 500).call

      expect(results).to include(shirt)
      expect(results).not_to include(macbook)
    end

    it 'filters by price range' do
      results = described_class.new.price_range(800, 1000).call

      expect(results).to include(iphone, galaxy)
      expect(results).not_to include(macbook, shirt)
    end
  end

  describe '#in_stock' do
    it 'filters in-stock products' do
      results = described_class.new.in_stock(true).call

      expect(results).to include(macbook, iphone)
      expect(results).not_to include(galaxy)
    end

    it 'filters out-of-stock products' do
      results = described_class.new.in_stock(false).call

      expect(results).to include(galaxy)
      expect(results).not_to include(macbook, iphone)
    end
  end

  describe '#search' do
    it 'searches by name' do
      results = described_class.new.search('MacBook').call

      expect(results).to include(macbook)
      expect(results).not_to include(iphone, galaxy)
    end

    it 'is case insensitive' do
      results = described_class.new.search('macbook').call

      expect(results).to include(macbook)
    end

    it 'handles special characters' do
      results = described_class.new.search('Mac%Book').call

      expect(results).to be_empty
    end
  end

  describe '#sorted_by' do
    it 'sorts by price ascending' do
      results = described_class.new.sorted_by(:price, :asc).call

      expect(results.first).to eq(shirt)
    end

    it 'sorts by price descending' do
      results = described_class.new.sorted_by(:price, :desc).call

      expect(results.first).to eq(macbook)
    end

    it 'defaults to asc for invalid direction' do
      results = described_class.new.sorted_by(:price, :invalid).call

      expect(results.first).to eq(shirt)
    end

    it 'defaults to name for invalid field' do
      results = described_class.new.sorted_by(:invalid_field, :asc).call

      expect(results.first).to eq(galaxy) # G comes before i, M, T
    end
  end

  describe 'chaining' do
    it 'chains multiple filters' do
      results = described_class.new
        .active
        .by_category('electronics')
        .by_brand('apple')
        .price_range(500, 1500)
        .in_stock(true)
        .call

      expect(results).to eq([iphone])
    end
  end

  describe '#paginate' do
    before { create_list(:product, 30) }

    it 'paginates results' do
      results = described_class.new.paginate(page: 2, per_page: 10).call

      expect(results.count).to eq(10)
    end

    it 'limits per_page to 100' do
      results = described_class.new.paginate(page: 1, per_page: 200).call

      expect(results.count).to be <= 100
    end
  end

  describe '#with_specification' do
    let!(:laptop_16gb) { create(:product, name: 'Laptop 16GB', specifications: { 'RAM' => '16GB' }) }
    let!(:laptop_8gb) { create(:product, name: 'Laptop 8GB', specifications: { 'RAM' => '8GB' }) }

    it 'filters by specification key-value' do
      results = described_class.new.with_specification('RAM', '16GB').call

      expect(results).to include(laptop_16gb)
      expect(results).not_to include(laptop_8gb)
    end

    it 'returns all when key is blank' do
      results = described_class.new.with_specification('', '16GB').call

      expect(results).to include(laptop_16gb, laptop_8gb)
    end

    it 'returns all when value is blank' do
      results = described_class.new.with_specification('RAM', '').call

      expect(results).to include(laptop_16gb, laptop_8gb)
    end
  end

  describe 'ApplicationQuery methods' do
    describe '#to_a' do
      it 'returns an array' do
        results = described_class.new.active.to_a

        expect(results).to be_an(Array)
        expect(results).to include(macbook)
      end
    end

    describe '#count' do
      it 'returns count of results' do
        count = described_class.new.active.count

        expect(count).to eq(3)
      end
    end

    describe '#exists?' do
      it 'returns true when results exist' do
        expect(described_class.new.active.exists?).to be true
      end

      it 'returns false when no results' do
        expect(described_class.new.by_category('nonexistent').exists?).to be false
      end
    end
  end
end

RSpec.describe ApplicationQuery do
  describe '#default_relation' do
    it 'raises NotImplementedError when called on base class' do
      query = described_class.allocate

      expect { query.send(:default_relation) }.to raise_error(NotImplementedError)
    end
  end
end
