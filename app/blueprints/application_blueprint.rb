# frozen_string_literal: true

# Base blueprint with common configuration
class ApplicationBlueprint < Blueprinter::Base
  # Use string keys for JSON output
  identifier :id

  # Transform keys to camelCase for JavaScript clients (optional)
  # transform Blueprinter::Transforms::CamelCase

  # Default date/time formatting
  def self.format_datetime(value)
    value&.iso8601
  end
end
