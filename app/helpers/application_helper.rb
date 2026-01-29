# frozen_string_literal: true

module ApplicationHelper
  # Simple markdown to HTML conversion for chat messages
  # Handles: **bold**, *italic*, `code`, lists, and line breaks
  def markdown_to_html(text)
    return '' if text.blank?

    html = ERB::Util.html_escape(text)

    # Headers (### and ##)
    html = html.gsub(/^### (.+)$/, '<h4 class="font-semibold text-gray-800 mt-3 mb-1">\1</h4>')
    html = html.gsub(/^## (.+)$/, '<h3 class="font-bold text-gray-900 mt-4 mb-2">\1</h3>')

    # Bold and italic
    html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    html = html.gsub(/\*(.+?)\*/, '<em>\1</em>')

    # Inline code
    html = html.gsub(/`([^`]+)`/, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm font-mono">\1</code>')

    # Unordered lists
    html = html.gsub(/^- (.+)$/, '<li class="ml-4">\1</li>')
    html = html.gsub(%r{(<li.*?</li>\n?)+}) { |match| "<ul class=\"list-disc my-2\">#{match}</ul>" }

    # Line breaks
    html = html.gsub("\n", '<br>')

    html.html_safe # rubocop:disable Rails/OutputSafety
  end
end
