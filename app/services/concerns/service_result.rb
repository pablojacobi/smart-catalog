# frozen_string_literal: true

# Service Result object for consistent service responses
# Implements the Result/Either pattern for explicit success/failure handling
#
# Usage:
#   class MyService
#     include ServiceResult
#
#     def call
#       # On success:
#       success(data: { user: user }, message: 'User created')
#
#       # On failure:
#       failure(error: 'Invalid email', code: :validation_error)
#     end
#   end
#
#   result = MyService.call
#   if result.success?
#     render json: result.data
#   else
#     render json: { error: result.error }, status: result.status
#   end
#
module ServiceResult
  extend ActiveSupport::Concern

  # Result object returned by services
  class Result
    attr_reader :data, :error, :code, :message, :metadata

    def initialize(success:, data: nil, error: nil, code: nil, message: nil, metadata: {})
      @success = success
      @data = data
      @error = error
      @code = code
      @message = message
      @metadata = metadata
      freeze
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    # HTTP status code based on error code
    def status
      return :ok if success?

      case code
      when :not_found then :not_found
      when :validation_error then :unprocessable_content
      when :unauthorized then :unauthorized
      when :forbidden then :forbidden
      when :rate_limited then :too_many_requests
      when :service_unavailable then :service_unavailable
      else :internal_server_error
      end
    end

    # Convert to hash for JSON serialization
    def to_h
      if success?
        { success: true, data: data, message: message, metadata: metadata }.compact
      else
        { success: false, error: error, code: code, message: message, metadata: metadata }.compact
      end
    end

    # Chainable methods for functional composition
    def and_then
      return self if failure?

      yield(data)
    end

    def or_else
      return self if success?

      yield(error)
    end

    def map
      return self if failure?

      self.class.new(success: true, data: yield(data), message: message, metadata: metadata)
    end
  end

  included do
    private

    # Create a success result
    #
    # @param data [Object] The result data
    # @param message [String] Optional success message
    # @param metadata [Hash] Optional metadata
    # @return [Result]
    def success(data: nil, message: nil, metadata: {})
      Result.new(success: true, data: data, message: message, metadata: metadata)
    end

    # Create a failure result
    #
    # @param error [String] Error message
    # @param code [Symbol] Error code for status mapping
    # @param message [String] Optional additional message
    # @param metadata [Hash] Optional metadata
    # @return [Result]
    def failure(error:, code: :internal_error, message: nil, metadata: {})
      Result.new(success: false, error: error, code: code, message: message, metadata: metadata)
    end
  end
end
