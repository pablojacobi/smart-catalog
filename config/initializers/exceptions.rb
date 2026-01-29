# frozen_string_literal: true

# Load custom exception classes
# These are defined within the SmartCatalog module namespace

module SmartCatalog
  # Base error class for all SmartCatalog errors
  class Error < StandardError
    attr_reader :code, :details

    def initialize(message = nil, code: nil, details: nil)
      @code = code
      @details = details
      super(message)
    end
  end

  # Record not found
  class NotFoundError < Error
    def initialize(message = 'Resource not found', **)
      super(message, code: 'not_found', **)
    end
  end

  # Validation failed
  class ValidationError < Error
    def initialize(message = 'Validation failed', **)
      super(message, code: 'validation_error', **)
    end
  end

  # Gemini API errors
  class GeminiError < Error
    def initialize(message = 'Gemini API error', **)
      super(message, code: 'gemini_error', **)
    end
  end

  # Rate limit exceeded
  class RateLimitError < Error
    def initialize(message = 'Rate limit exceeded', **)
      super(message, code: 'rate_limit_exceeded', **)
    end
  end

  # Authentication error
  class AuthenticationError < Error
    def initialize(message = 'Authentication failed', **)
      super(message, code: 'authentication_error', **)
    end
  end

  # Service unavailable
  class ServiceUnavailableError < Error
    def initialize(message = 'Service temporarily unavailable', **)
      super(message, code: 'service_unavailable', **)
    end
  end

  # Document processing error
  class ProcessingError < Error
    def initialize(message = 'Document processing failed', **)
      super(message, code: 'processing_error', **)
    end
  end
end
