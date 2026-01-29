# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::StreamingService do
  let(:gemini_client) { instance_double(Gemini::ClientService) }
  let(:context_builder) { instance_double(Chat::ContextBuilderService) }
  let(:classifier) { instance_double(Chat::QueryClassifierService) }
  let(:service) do
    described_class.new(
      gemini_client: gemini_client,
      context_builder: context_builder,
      classifier: classifier
    )
  end

  let(:conversation) { create(:conversation) }
  let!(:category) { create(:category, name: 'Laptops', slug: 'laptops') }
  let!(:product) { create(:product, name: 'Test Laptop', category: category, price: 999.99) }

  describe '#call' do
    let(:classification) do
      {
        query_type: 'listing',
        filters: { category: 'laptops' },
        search_query: 'laptop'
      }
    end

    let(:context) do
      {
        statistics: { total: 10, in_stock_count: 8 },
        products: [product],
        markdown: "## Catalog Overview\n- Total: 10\n\n## Products\n1. Test Laptop"
      }
    end

    before do
      allow(classifier).to receive(:call).and_return(classification)
      allow(context_builder).to receive(:call).and_return(context)
    end

    context 'when streaming succeeds' do
      before do
        allow(gemini_client).to receive(:stream_content).and_yield('Here are ').and_yield('some laptops')
      end

      it 'yields chunks to the block' do
        chunks = []
        service.call(conversation: conversation, message: 'show me laptops') do |chunk|
          chunks << chunk
        end

        expect(chunks).to eq(['Here are ', 'some laptops'])
      end

      it 'returns result with content' do
        result = service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        expect(result[:content]).to eq('Here are some laptops')
        expect(result[:conversation_id]).to eq(conversation.id)
      end

      it 'returns product IDs' do
        result = service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        expect(result[:product_ids]).to include(product.id)
      end

      it 'returns statistics' do
        result = service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        expect(result[:statistics]).to eq(context[:statistics])
      end

      it 'returns duration in milliseconds' do
        result = service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        expect(result[:duration_ms]).to be_a(Integer)
        expect(result[:duration_ms]).to be >= 0
      end

      it 'stores user message in conversation' do
        service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        user_message = conversation.messages.find_by(role: 'user')
        expect(user_message.content).to eq('show me laptops')
      end

      it 'stores assistant message in conversation' do
        service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        assistant_message = conversation.messages.find_by(role: 'assistant')
        expect(assistant_message.content).to eq('Here are some laptops')
      end

      it 'stores product IDs in message metadata' do
        service.call(conversation: conversation, message: 'show me laptops') { |chunk| chunk }

        assistant_message = conversation.messages.find_by(role: 'assistant')
        expect(assistant_message.metadata['product_ids']).to include(product.id)
      end
    end

    context 'when classifier extracts filters' do
      before do
        allow(gemini_client).to receive(:stream_content).and_yield('Result')
      end

      it 'uses search_query from classification' do
        service.call(conversation: conversation, message: 'laptops under $1000') { |chunk| chunk }

        # Context builder receives the search_query from classifier
        expect(context_builder).to have_received(:call)
      end
    end

    context 'with conversation history' do
      let(:conversation_with_history) { create(:conversation) }

      before do
        conversation_with_history.add_message(role: 'user', content: 'hello')
        conversation_with_history.add_message(
          role: 'assistant',
          content: 'Hi there!',
          metadata: { 'product_ids' => [product.id] }
        )
        allow(gemini_client).to receive(:stream_content).and_yield('Result')
      end

      it 'builds context from previous messages' do
        service.call(conversation: conversation_with_history, message: 'show me more') { |chunk| chunk }

        # Verifies that classifier was called
        expect(classifier).to have_received(:call)
      end
    end
  end

  describe '#call_sync' do
    let(:classification) { { query_type: 'listing', filters: {}, search_query: '' } }
    let(:context) { { statistics: {}, products: [], markdown: '' } }

    before do
      allow(classifier).to receive(:call).and_return(classification)
      allow(context_builder).to receive(:call).and_return(context)
      allow(gemini_client).to receive(:stream_content).and_yield('Test response')
    end

    it 'returns complete response without streaming' do
      result = service.call_sync(conversation: conversation, message: 'test')

      expect(result[:content]).to eq('Test response')
      expect(result[:conversation_id]).to eq(conversation.id)
    end
  end

  describe 'contextual queries' do
    let(:conversation_with_products) { create(:conversation) }
    let!(:brand) { create(:brand, name: 'TestBrand') }
    let!(:previous_product) do
      create(:product, name: 'Previous Laptop', category: category, brand: brand, price: 1500.00,
                       in_stock: true, specifications: { 'cpu' => 'i7', 'ram_gb' => '16' })
    end

    before do
      # Add a message with product_ids metadata
      conversation_with_products.add_message(
        role: 'assistant',
        content: 'Here is a laptop',
        metadata: { 'product_ids' => [previous_product.id] }
      )
    end

    context 'when query is contextual with previous products' do
      let(:contextual_classification) do
        {
          query_type: 'contextual',
          filters: {},
          search_query: 'which is cheaper'
        }
      end

      before do
        allow(classifier).to receive(:call).and_return(contextual_classification)
        allow(context_builder).to receive(:call) # Allow but should not be called
        allow(gemini_client).to receive(:stream_content).and_yield('The previous laptop costs $1500')
      end

      it 'uses previous products instead of searching new ones' do
        result = service.call(
          conversation: conversation_with_products,
          message: 'which one is cheaper?'
        ) { |chunk| chunk }

        expect(result[:product_ids]).to eq([previous_product.id])
        expect(context_builder).not_to have_received(:call)
      end

      it 'includes previous products in context markdown' do
        service.call(
          conversation: conversation_with_products,
          message: 'which one is cheaper?'
        ) { |chunk| chunk }

        # Verify gemini client received messages containing previous product info
        expect(gemini_client).to have_received(:stream_content) do |messages, **_opts|
          context_message = messages.last[:content]
          expect(context_message).to include('Products from previous response')
          expect(context_message).to include('Previous Laptop')
          expect(context_message).to include('TestBrand')
          expect(context_message).to include('$1500')
        end
      end
    end

    context 'when query is contextual but no previous products' do
      let(:empty_conversation) { create(:conversation) }
      let(:contextual_classification) do
        {
          query_type: 'contextual',
          filters: {},
          search_query: 'which is cheaper'
        }
      end
      let(:fallback_context) do
        {
          statistics: { total: 5 },
          products: [product],
          markdown: '## Products'
        }
      end

      before do
        allow(classifier).to receive(:call).and_return(contextual_classification)
        allow(context_builder).to receive(:call).and_return(fallback_context)
        allow(gemini_client).to receive(:stream_content).and_yield('Here are products')
      end

      it 'falls back to context builder' do
        service.call(
          conversation: empty_conversation,
          message: 'which one is cheaper?'
        ) { |chunk| chunk }

        expect(context_builder).to have_received(:call)
      end
    end

    context 'when product has no price' do
      let!(:product_no_price) do
        create(:product, name: 'No Price Product', category: category, price: nil, in_stock: false)
      end

      before do
        conversation_with_products.messages.last.update!(metadata: { 'product_ids' => [product_no_price.id] })
        allow(classifier).to receive(:call).and_return({ query_type: 'contextual', filters: {}, search_query: '' })
        allow(gemini_client).to receive(:stream_content).and_yield('Response')
      end

      it 'handles products without price' do
        service.call(
          conversation: conversation_with_products,
          message: 'tell me about this'
        ) { |chunk| chunk }

        expect(gemini_client).to have_received(:stream_content) do |messages, **_opts|
          context_message = messages.last[:content]
          expect(context_message).to include('N/A')
          expect(context_message).to include('Out of Stock')
        end
      end
    end
  end

  describe 'calling without block' do
    let(:classification) { { query_type: 'listing', filters: {}, search_query: '' } }
    let(:context) { { statistics: {}, products: [product], markdown: '' } }

    before do
      allow(classifier).to receive(:call).and_return(classification)
      allow(context_builder).to receive(:call).and_return(context)
      allow(gemini_client).to receive(:stream_content).and_yield('Test')
    end

    it 'works without a block' do
      # Should not raise
      result = service.call(conversation: conversation, message: 'test')
      expect(result[:content]).to eq('Test')
    end
  end
end
