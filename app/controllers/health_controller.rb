# frozen_string_literal: true

class HealthController < ApplicationController
  def show
    checks = {
      database: database_check,
      migrations: migrations_check
    }

    status = checks.values.all? ? :ok : :service_unavailable

    render json: {
      status: status == :ok ? 'healthy' : 'unhealthy',
      version: app_version,
      environment: Rails.env,
      checks: checks,
      stats: stats,
      timestamp: Time.current.iso8601
    }, status: status
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError
    false
  end

  def migrations_check
    # In test/development, migrations may show as pending due to environment issues
    # This check is most useful in production
    return true if Rails.env.test? || Rails.env.development?

    !ActiveRecord::Base.connection.migration_context.needs_migration?
  rescue StandardError
    false
  end

  def app_version
    {
      ruby: RUBY_VERSION,
      rails: Rails.version,
      app: ENV.fetch('APP_VERSION', 'development')
    }
  end

  def stats
    {
      products: Product.count,
      categories: Category.count,
      brands: Brand.count
    }
  rescue StandardError
    {}
  end
end
