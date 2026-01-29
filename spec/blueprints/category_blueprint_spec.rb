# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryBlueprint do
  let(:category) { create(:category, name: 'Electronics', slug: 'electronics', description: 'Electronic devices') }

  describe 'default view' do
    subject(:result) { described_class.render_as_hash(category) }

    it 'includes basic fields' do
      expect(result[:id]).to eq(category.id)
      expect(result[:name]).to eq('Electronics')
      expect(result[:slug]).to eq('electronics')
    end
  end

  describe 'normal view' do
    subject(:result) { described_class.render_as_hash(category, view: :normal) }

    it 'includes description' do
      expect(result[:description]).to eq('Electronic devices')
    end

    it 'includes products_count' do
      create_list(:product, 5, category: category)
      result = described_class.render_as_hash(category, view: :normal)

      expect(result[:products_count]).to eq(5)
    end
  end

  describe 'extended view' do
    subject(:result) { described_class.render_as_hash(category, view: :extended) }

    it 'includes normal view fields' do
      expect(result[:description]).to eq('Electronic devices')
    end

    it 'includes timestamps' do
      expect(result[:created_at]).to be_present
      expect(result[:updated_at]).to be_present
    end
  end

  describe 'collection rendering' do
    let(:categories) { create_list(:category, 4) }

    it 'renders array of categories' do
      result = described_class.render_as_hash(categories)

      expect(result).to be_an(Array)
      expect(result.length).to eq(4)
    end
  end
end
