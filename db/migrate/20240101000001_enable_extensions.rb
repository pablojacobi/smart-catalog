# frozen_string_literal: true

class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Only enable vector extension if available (requires pgvector installed on server)
    if vector_extension_available?
      enable_extension 'vector' unless extension_enabled?('vector')
    else
      Rails.logger.warn('[Migration] pgvector extension not available on this PostgreSQL server')
    end
  end

  private

  def vector_extension_available?
    result = execute("SELECT 1 FROM pg_available_extensions WHERE name = 'vector'")
    result.any?
  rescue StandardError
    false
  end
end
