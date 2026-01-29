# frozen_string_literal: true

# Pagination concern for API controllers
# Provides consistent pagination across endpoints
module Pagination
  extend ActiveSupport::Concern

  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  included do
    helper_method :pagination_params if respond_to?(:helper_method)
  end

  private

  def pagination_params
    @pagination_params ||= {
      page: current_page,
      per_page: per_page
    }
  end

  def current_page
    [params[:page].to_i, DEFAULT_PAGE].max
  end

  def per_page
    requested = params[:per_page].to_i
    return DEFAULT_PER_PAGE if requested <= 0

    [requested, MAX_PER_PAGE].min
  end

  def paginate(collection)
    total = collection.count
    offset = (current_page - 1) * per_page
    paginated = collection.offset(offset).limit(per_page)

    {
      data: paginated,
      meta: pagination_meta(total)
    }
  end

  def pagination_meta(total)
    total_pages = (total.to_f / per_page).ceil

    {
      current_page: current_page,
      per_page: per_page,
      total_count: total,
      total_pages: total_pages,
      has_next_page: current_page < total_pages,
      has_prev_page: current_page > 1
    }
  end
end
