# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrandBlueprint do
  let(:brand) { create(:brand, name: 'Apple', slug: 'apple', description: 'Tech company') }

  describe 'default view' do
    subject(:result) { described_class.render_as_hash(brand) }

    it 'includes basic fields' do
      expect(result[:id]).to eq(brand.id)
      expect(result[:name]).to eq('Apple')
      expect(result[:slug]).to eq('apple')
    end
  end

  describe 'normal view' do
    subject(:result) { described_class.render_as_hash(brand, view: :normal) }

    it 'includes description' do
      expect(result[:description]).to eq('Tech company')
    end

    it 'includes products_count' do
      create_list(:product, 3, brand: brand)
      result = described_class.render_as_hash(brand, view: :normal)

      expect(result[:products_count]).to eq(3)
    end
  end

  describe 'extended view' do
    subject(:result) { described_class.render_as_hash(brand, view: :extended) }

    it 'includes normal view fields' do
      expect(result[:description]).to eq('Tech company')
    end

    it 'includes timestamps' do
      expect(result[:created_at]).to be_present
      expect(result[:updated_at]).to be_present
    end
  end

  describe 'collection rendering' do
    let(:brands) { create_list(:brand, 3) }

    it 'renders array of brands' do
      result = described_class.render_as_hash(brands)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end
  end
end
