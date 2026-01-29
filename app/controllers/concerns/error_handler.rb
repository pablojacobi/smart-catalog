# frozen_string_literal: true

# Centralized error handling for API controllers
# Provides consistent error responses across the application
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from SmartCatalog::Error, with: :handle_smart_catalog_error
  end

  private

  def handle_standard_error(exception)
    Rails.logger.error("[#{exception.class}] #{exception.message}")
    Rails.logger.error(exception.backtrace.first(10).join("\n")) if Rails.env.development?

    render_error(
      message: Rails.env.production? ? 'An unexpected error occurred' : exception.message,
      code: 'internal_error',
      status: :internal_server_error
    )
  end

  def handle_not_found(exception)
    render_error(
      message: exception.message || 'Resource not found',
      code: 'not_found',
      status: :not_found
    )
  end

  def handle_validation_error(exception)
    render_error(
      message: 'Validation failed',
      code: 'validation_error',
      status: :unprocessable_content,
      details: exception.record&.errors&.full_messages
    )
  end

  def handle_parameter_missing(exception)
    render_error(
      message: exception.message,
      code: 'parameter_missing',
      status: :bad_request
    )
  end

  def handle_smart_catalog_error(exception)
    status = case exception
             when SmartCatalog::NotFoundError then :not_found
             when SmartCatalog::ValidationError then :unprocessable_content
             when SmartCatalog::AuthenticationError then :unauthorized
             when SmartCatalog::RateLimitError then :too_many_requests
             when SmartCatalog::ServiceUnavailableError then :service_unavailable
             else :internal_server_error
             end

    render_error(
      message: exception.message,
      code: exception.code,
      status: status,
      details: exception.details
    )
  end

  def render_error(message:, code:, status:, details: nil)
    response_body = {
      error: {
        message: message,
        code: code
      }
    }
    response_body[:error][:details] = details if details.present?

    render json: response_body, status: status
  end

  # Helper to render success responses with optional message
  def render_success(data:, status: :ok, message: nil, meta: nil)
    response_body = { data: data }
    response_body[:message] = message if message.present?
    response_body[:meta] = meta if meta.present?

    render json: response_body, status: status
  end
end
