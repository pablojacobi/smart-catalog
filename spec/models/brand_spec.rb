# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Brand do
  describe 'validations' do
    subject { build(:brand) }

    it { is_expected.to validate_presence_of(:name) }
    # NOTE: slug is auto-generated from name, so presence validation always passes
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:products).dependent(:nullify) }
  end

  describe 'callbacks' do
    describe '#generate_slug' do
      it 'generates slug from name on create' do
        brand = build(:brand, name: 'Apple Inc.', slug: nil)
        brand.valid?
        expect(brand.slug).to eq('apple-inc')
      end
    end
  end

  describe 'scopes' do
    describe '.with_products' do
      it 'returns brands that have products' do
        brand_with = create(:brand)
        brand_without = create(:brand)
        create(:product, brand: brand_with)

        expect(described_class.with_products).to include(brand_with)
        expect(described_class.with_products).not_to include(brand_without)
      end
    end

    describe '.ordered' do
      it 'returns brands ordered by name' do
        zebra = create(:brand, name: 'Zebra')
        apple = create(:brand, name: 'Apple')
        microsoft = create(:brand, name: 'Microsoft')

        expect(described_class.ordered.to_a).to eq([apple, microsoft, zebra])
      end
    end
  end

  describe '#to_param' do
    it 'returns the slug' do
      brand = create(:brand, slug: 'apple-inc')
      expect(brand.to_param).to eq('apple-inc')
    end
  end
end
