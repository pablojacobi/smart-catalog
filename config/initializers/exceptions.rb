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
    def initialize(message = 'Resource not found', **kwargs)
      super(message, code: 'not_found', **kwargs)
    end
  end

  # Validation failed
  class ValidationError < Error
    def initialize(message = 'Validation failed', **kwargs)
      super(message, code: 'validation_error', **kwargs)
    end
  end

  # Gemini API errors
  class GeminiError < Error
    def initialize(message = 'Gemini API error', **kwargs)
      super(message, code: 'gemini_error', **kwargs)
    end
  end

  # Rate limit exceeded
  class RateLimitError < Error
    def initialize(message = 'Rate limit exceeded', **kwargs)
      super(message, code: 'rate_limit_exceeded', **kwargs)
    end
  end

  # Authentication error
  class AuthenticationError < Error
    def initialize(message = 'Authentication failed', **kwargs)
      super(message, code: 'authentication_error', **kwargs)
    end
  end

  # Service unavailable
  class ServiceUnavailableError < Error
    def initialize(message = 'Service temporarily unavailable', **kwargs)
      super(message, code: 'service_unavailable', **kwargs)
    end
  end

  # Document processing error
  class ProcessingError < Error
    def initialize(message = 'Document processing failed', **kwargs)
      super(message, code: 'processing_error', **kwargs)
    end
  end
end
