# frozen_string_literal: true

module API
  module V1
    # Documents controller (read-only in this demo version)
    # Full version includes: upload, OCR processing, reprocessing
    class DocumentsController < BaseController
      # GET /api/v1/documents
      def index
        query = DocumentQuery.new
          .by_status(params[:status])
          .search(params[:q])
          .recent
          .with_associations

        result = paginate(query.call)

        render_collection(
          result[:data],
          blueprint: DocumentBlueprint,
          view: :normal,
          meta: result[:meta]
        )
      end

      # GET /api/v1/documents/:id
      def show
        document = Document.includes(:products).find(params[:id])

        render_resource(document, blueprint: DocumentBlueprint, view: :extended)
      end
    end
  end
end
