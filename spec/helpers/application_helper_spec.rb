# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#markdown_to_html' do
    it 'returns empty string for blank input' do
      expect(helper.markdown_to_html(nil)).to eq('')
      expect(helper.markdown_to_html('')).to eq('')
    end

    it 'escapes HTML entities' do
      expect(helper.markdown_to_html('<script>alert("xss")</script>')).not_to include('<script>')
    end

    it 'converts ## headers' do
      html = helper.markdown_to_html('## Header')
      expect(html).to include('<h3')
      expect(html).to include('Header')
    end

    it 'converts ### headers' do
      html = helper.markdown_to_html('### Subheader')
      expect(html).to include('<h4')
      expect(html).to include('Subheader')
    end

    it 'converts **bold** text' do
      html = helper.markdown_to_html('This is **bold** text')
      expect(html).to include('<strong>bold</strong>')
    end

    it 'converts *italic* text' do
      html = helper.markdown_to_html('This is *italic* text')
      expect(html).to include('<em>italic</em>')
    end

    it 'converts `inline code`' do
      html = helper.markdown_to_html('Use `code` here')
      expect(html).to include('<code')
      expect(html).to include('code')
    end

    it 'converts unordered list items' do
      html = helper.markdown_to_html("- Item 1\n- Item 2")
      expect(html).to include('<li')
      expect(html).to include('Item 1')
    end

    it 'converts newlines to <br>' do
      html = helper.markdown_to_html("Line 1\nLine 2")
      expect(html).to include('<br>')
    end

    it 'returns html_safe string' do
      result = helper.markdown_to_html('Test')
      expect(result).to be_html_safe
    end
  end
end
