# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ServiceResult do
  let(:test_class) do
    Class.new do
      include ServiceResult

      def success_example
        success(data: { id: 1 }, message: 'Created successfully')
      end

      def failure_example
        failure(error: 'Something went wrong', code: :validation_error)
      end
    end
  end

  let(:service) { test_class.new }

  describe ServiceResult::Result do
    describe '#success?' do
      it 'returns true for success results' do
        result = service.success_example
        expect(result.success?).to be true
      end

      it 'returns false for failure results' do
        result = service.failure_example
        expect(result.success?).to be false
      end
    end

    describe '#failure?' do
      it 'returns false for success results' do
        result = service.success_example
        expect(result.failure?).to be false
      end

      it 'returns true for failure results' do
        result = service.failure_example
        expect(result.failure?).to be true
      end
    end

    describe '#data' do
      it 'returns data for success results' do
        result = service.success_example
        expect(result.data).to eq({ id: 1 })
      end
    end

    describe '#error' do
      it 'returns error for failure results' do
        result = service.failure_example
        expect(result.error).to eq('Something went wrong')
      end
    end

    describe '#status' do
      it 'returns :ok for success' do
        result = service.success_example
        expect(result.status).to eq(:ok)
      end

      it 'returns appropriate status for error codes' do
        test_cases = {
          not_found: :not_found,
          validation_error: :unprocessable_content,
          unauthorized: :unauthorized,
          forbidden: :forbidden,
          rate_limited: :too_many_requests,
          service_unavailable: :service_unavailable,
          unknown: :internal_server_error
        }

        test_cases.each do |code, expected_status|
          result = ServiceResult::Result.new(success: false, error: 'test', code: code)
          expect(result.status).to eq(expected_status), "Expected #{code} to map to #{expected_status}"
        end
      end
    end

    describe '#to_h' do
      it 'returns hash representation for success' do
        result = service.success_example
        hash = result.to_h

        expect(hash[:success]).to be true
        expect(hash[:data]).to eq({ id: 1 })
        expect(hash[:message]).to eq('Created successfully')
      end

      it 'returns hash representation for failure' do
        result = service.failure_example
        hash = result.to_h

        expect(hash[:success]).to be false
        expect(hash[:error]).to eq('Something went wrong')
        expect(hash[:code]).to eq(:validation_error)
      end
    end

    describe '#and_then' do
      it 'yields data on success' do
        result = service.success_example
        new_result = result.and_then { |data| ServiceResult::Result.new(success: true, data: data[:id] * 2) }

        expect(new_result.data).to eq(2)
      end

      it 'returns self on failure' do
        result = service.failure_example
        new_result = result.and_then { |_data| raise 'Should not be called' }

        expect(new_result).to eq(result)
      end
    end

    describe '#map' do
      it 'transforms data on success' do
        result = service.success_example
        new_result = result.map { |data| data[:id] * 10 }

        expect(new_result.data).to eq(10)
        expect(new_result.success?).to be true
      end

      it 'returns self on failure' do
        result = service.failure_example
        new_result = result.map { |_data| raise 'Should not be called' }

        expect(new_result).to eq(result)
      end
    end

    describe '#or_else' do
      it 'returns self on success' do
        result = service.success_example
        new_result = result.or_else { |_error| raise 'Should not be called' }

        expect(new_result).to eq(result)
      end

      it 'yields error on failure' do
        result = service.failure_example
        new_result = result.or_else { |error| ServiceResult::Result.new(success: true, data: "recovered from: #{error}") }

        expect(new_result.success?).to be true
        expect(new_result.data).to eq('recovered from: Something went wrong')
      end
    end
  end
end
