# frozen_string_literal: true

ActiveSupport::Inflector.inflections(:en) do |inflect|
  # Note: 'API' acronym removed to match Zeitwerk expectations (Api::V1 instead of API::V1)
  inflect.acronym 'OCR'
  inflect.acronym 'PDF'
end
