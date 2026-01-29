# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::OrchestratorService do
  let(:classifier) { instance_double(Chat::QueryClassifierService) }
  let(:search_service) { instance_double(Search::HybridSearchService) }
  let(:sql_service) { instance_double(Search::SqlSearchService) }
  let(:response_builder) { instance_double(Chat::ResponseBuilderService) }

  let(:service) do
    described_class.new(
      classifier: classifier,
      search_service: search_service,
      sql_service: sql_service,
      response_builder: response_builder
    )
  end

  describe '#call' do
    let(:conversation) { create(:conversation) }
    let(:products) { create_list(:product, 3) }

    before do
      allow(classifier).to receive(:call).and_return({
                                                       query_type: 'listing',
                                                       filters: {},
                                                       search_query: 'laptops'
                                                     })

      allow(search_service).to receive(:call).and_return(
        products.map { |p| { product: p, score: 0.9, source: 'hybrid' } }
      )

      allow(response_builder).to receive(:call).and_return({
                                                             content: 'Here are some products',
                                                             product_ids: products.map(&:id),
                                                             response_type: 'listing'
                                                           })
    end

    it 'processes a chat message and returns response' do
      result = service.call(conversation: conversation, message: 'Show me laptops')

      expect(result[:content]).to eq('Here are some products')
      expect(result[:conversation_id]).to eq(conversation.id)
    end

    it 'saves user and assistant messages' do
      expect do
        service.call(conversation: conversation, message: 'Show me laptops')
      end.to change(conversation.messages, :count).by(2)

      messages = conversation.messages.ordered
      expect(messages.first.role).to eq('user')
      expect(messages.last.role).to eq('assistant')
    end

    it 'includes metadata in response' do
      result = service.call(conversation: conversation, message: 'Show me laptops')

      expect(result[:metadata]).to include(:query_type, :product_count, :duration_ms)
    end

    context 'with count query' do
      before do
        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'count',
                                                         filters: {},
                                                         search_query: ''
                                                       })

        allow(sql_service).to receive(:count).and_return({ total: 100 })
      end

      it 'uses count strategy' do
        service.call(conversation: conversation, message: 'How many products?')

        expect(sql_service).to have_received(:count)
      end
    end

    context 'with contextual query' do
      let(:previous_products) { create_list(:product, 5, price: 500) }

      before do
        create(:message, :assistant, conversation: conversation,
                                     metadata: { 'product_ids' => previous_products.map(&:id) })

        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'contextual',
                                                         filters: { max_price: 300 },
                                                         search_query: ''
                                                       })
      end

      it 'filters previous products' do
        allow(response_builder).to receive(:call) do |args|
          expect(args[:products]).to be_empty # All products are $500, filter is max $300
          { content: 'No products', product_ids: [], response_type: 'contextual' }
        end

        service.call(conversation: conversation, message: 'From those, under $300')
      end
    end

    context 'with conversational query' do
      before do
        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'conversational',
                                                         filters: {},
                                                         search_query: ''
                                                       })

        allow(response_builder).to receive(:call).and_return({
                                                               content: 'Hello! How can I help?',
                                                               product_ids: [],
                                                               response_type: 'conversational'
                                                             })
      end

      it 'returns conversational response without products' do
        result = service.call(conversation: conversation, message: 'Hello!')

        expect(result[:content]).to eq('Hello! How can I help?')
        expect(response_builder).to have_received(:call).with(hash_including(products: []))
      end
    end

    context 'with contextual filtering edge cases' do
      let(:category) { create(:category, name: 'Electronics', slug: 'electronics') }
      let(:brand) { create(:brand, name: 'Apple', slug: 'apple') }
      let!(:product_in_stock) { create(:product, price: 200, in_stock: true, category: category, brand: brand) }
      let!(:product_out_of_stock) { create(:product, price: 200, in_stock: false, category: category) }
      let!(:product_expensive) { create(:product, price: 1000, in_stock: true, category: category) }
      let!(:product_cheap) { create(:product, price: 50, in_stock: true, category: category) }

      before do
        create(:message, :assistant, conversation: conversation,
                                     metadata: { 'product_ids' => [product_in_stock.id, product_out_of_stock.id, product_expensive.id, product_cheap.id] })
      end

      it 'filters by in_stock requirement' do
        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'contextual',
                                                         filters: { in_stock: true },
                                                         search_query: ''
                                                       })

        allow(response_builder).to receive(:call) do |args|
          expect(args[:products]).not_to include(product_out_of_stock)
          expect(args[:products]).to include(product_in_stock)
          { content: 'Filtered', product_ids: [], response_type: 'contextual' }
        end

        service.call(conversation: conversation, message: 'Only in stock')
      end

      it 'filters by min_price' do
        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'contextual',
                                                         filters: { min_price: 100 },
                                                         search_query: ''
                                                       })

        allow(response_builder).to receive(:call) do |args|
          expect(args[:products]).not_to include(product_cheap)
          expect(args[:products]).to include(product_in_stock, product_expensive)
          { content: 'Filtered', product_ids: [], response_type: 'contextual' }
        end

        service.call(conversation: conversation, message: 'Above $100')
      end

      it 'filters by category' do
        other_category = create(:category, name: 'Clothing', slug: 'clothing')
        product_other = create(:product, category: other_category)
        create(:message, :assistant, conversation: conversation,
                                     metadata: { 'product_ids' => [product_in_stock.id, product_other.id] })

        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'contextual',
                                                         filters: { category: 'electronics' },
                                                         search_query: ''
                                                       })

        allow(response_builder).to receive(:call) do |args|
          expect(args[:products]).not_to include(product_other)
          { content: 'Filtered', product_ids: [], response_type: 'contextual' }
        end

        service.call(conversation: conversation, message: 'Just electronics')
      end

      it 'filters by brand' do
        other_brand = create(:brand, name: 'Samsung', slug: 'samsung')
        product_other = create(:product, brand: other_brand)
        create(:message, :assistant, conversation: conversation,
                                     metadata: { 'product_ids' => [product_in_stock.id, product_other.id] })

        allow(classifier).to receive(:call).and_return({
                                                         query_type: 'contextual',
                                                         filters: { brand: 'apple' },
                                                         search_query: ''
                                                       })

        allow(response_builder).to receive(:call) do |args|
          expect(args[:products]).not_to include(product_other)
          { content: 'Filtered', product_ids: [], response_type: 'contextual' }
        end

        service.call(conversation: conversation, message: 'Just Apple')
      end
    end
  end
end
