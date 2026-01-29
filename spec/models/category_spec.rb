# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category do
  describe 'validations' do
    subject { build(:category) }

    it { is_expected.to validate_presence_of(:name) }
    # Note: slug is auto-generated from name, so presence validation always passes
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:products).dependent(:nullify) }
  end

  describe 'callbacks' do
    describe '#generate_slug' do
      it 'generates slug from name on create' do
        category = build(:category, name: 'Electronics & Gadgets', slug: nil)
        category.valid?
        expect(category.slug).to eq('electronics-gadgets')
      end

      it 'does not override existing slug' do
        category = build(:category, name: 'Electronics', slug: 'custom-slug')
        category.valid?
        expect(category.slug).to eq('custom-slug')
      end
    end
  end

  describe 'scopes' do
    describe '.with_products' do
      it 'returns categories that have products' do
        category_with = create(:category)
        category_without = create(:category)
        create(:product, category: category_with)

        expect(described_class.with_products).to include(category_with)
        expect(described_class.with_products).not_to include(category_without)
      end
    end

    describe '.ordered' do
      it 'returns categories ordered by name' do
        create(:category, name: 'Zebra')
        create(:category, name: 'Apple')

        names = described_class.ordered.pluck(:name)
        expect(names).to eq(%w[Apple Zebra])
      end
    end
  end

  describe '#to_param' do
    it 'returns the slug' do
      category = build(:category, slug: 'electronics')
      expect(category.to_param).to eq('electronics')
    end
  end
end
