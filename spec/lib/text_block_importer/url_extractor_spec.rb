# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TextBlockImporter::UrlExtractor do
  let(:http_client) { instance_double(TextBlockImporter::HttpClient) }
  
  subject { described_class.new(http_client) }

  describe '#initialize' do
    it 'creates a new instance with HTTP client' do
      extractor = described_class.new(http_client)
      expect(extractor).to be_an_instance_of(described_class)
    end

    it 'creates default HTTP client when none provided' do
      expect(TextBlockImporter::HttpClient).to receive(:new)
      described_class.new
    end
  end

  describe '#extract' do
    let(:url) { 'https://example.com/page' }
    let(:selector) { 'nav a' }

    context 'with valid HTML containing links' do
      let(:html_with_links) do
        <<~HTML
          <html>
          <body>
            <nav>
              <a href="/page1">Page 1</a>
              <a href="/page2">Page 2</a>
              <a href="https://example.com/page3">Page 3</a>
              <a href="https://external.com/page">External</a>
            </nav>
          </body>
          </html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(html_with_links)
      end

      it 'extracts URLs from the specified selector' do
        result = subject.extract(url, selector)
        
        expect(result).to be_an(Array)
        expect(result).to include('https://example.com/page1')
        expect(result).to include('https://example.com/page2')
        expect(result).to include('https://example.com/page3')
      end

      it 'converts relative URLs to absolute URLs' do
        result = subject.extract(url, selector)
        
        expect(result).to include('https://example.com/page1')
        expect(result).to include('https://example.com/page2')
        expect(result).not_to include('/page1')
        expect(result).not_to include('/page2')
      end

      it 'preserves absolute URLs from same domain' do
        result = subject.extract(url, selector)
        
        expect(result).to include('https://example.com/page3')
      end

      it 'excludes external domain URLs' do
        result = subject.extract(url, selector)
        
        expect(result).not_to include('https://external.com/page')
      end

      it 'processes content by stripping newlines' do
        html_with_newlines = <<~HTML
          <html>
          <body>
            <nav>
              <a href="/page1">
                Page 1
              </a>
              <a href="/page2">Page 2</a>
            </nav>
          </body>
          </html>
        HTML

        allow(http_client).to receive(:fetch).with(url).and_return(html_with_newlines)

        result = subject.extract(url, selector)
        expect(result).to include('https://example.com/page1')
        expect(result).to include('https://example.com/page2')
      end
    end

    context 'with different URL formats' do
      let(:html_with_various_urls) do
        <<~HTML
          <html>
          <body>
            <div class="links">
              <a href="/simple">Simple relative</a>
              <a href="/path/with/multiple/segments">Deep relative</a>
              <a href="https://example.com/absolute-same-domain">Absolute same domain</a>
              <a href="mailto:test@example.com">Email link</a>
              <a href="javascript:void(0)">JavaScript link</a>
              <a href="#anchor">Anchor link</a>
              <a href="?query=param">Query only</a>
            </div>
          </body>
          </html>
        HTML
      end

      let(:selector) { '.links a' }

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(html_with_various_urls)
      end

      it 'handles various URL formats correctly' do
        result = subject.extract(url, selector)
        
        expect(result).to include('https://example.com/simple')
        expect(result).to include('https://example.com/path/with/multiple/segments')
        expect(result).to include('https://example.com/absolute-same-domain')
        
        # Should not include non-HTTP URLs
        expect(result).not_to include('mailto:test@example.com')
        expect(result).not_to include('javascript:void(0)')
        expect(result).not_to include('#anchor')
        expect(result).not_to include('?query=param')
      end
    end

    context 'with single and double quotes in href attributes' do
      let(:html_with_quoted_urls) do
        <<~HTML
          <html>
          <body>
            <div>
              <a href="/single-quotes">Single quotes</a>
              <a href="/double-quotes">Double quotes</a>
              <a href='https://example.com/single-quoted-absolute'>Single quoted absolute</a>
            </div>
          </body>
          </html>
        HTML
      end

      let(:selector) { 'div a' }

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(html_with_quoted_urls)
      end

      it 'handles both single and double quoted href attributes' do
        result = subject.extract(url, selector)
        
        expect(result).to include('https://example.com/single-quotes')
        expect(result).to include('https://example.com/double-quotes')
        expect(result).to include('https://example.com/single-quoted-absolute')
      end
    end

    context 'with complex selectors' do
      let(:complex_html) do
        <<~HTML
          <html>
          <body>
            <nav class="primary">
              <a href="/nav1">Nav 1</a>
              <a href="/nav2">Nav 2</a>
            </nav>
            <aside>
              <a href="/sidebar1">Sidebar 1</a>
            </aside>
            <footer>
              <nav class="secondary">
                <a href="/footer1">Footer 1</a>
              </nav>
            </footer>
          </body>
          </html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(complex_html)
      end

      it 'extracts URLs only from specified selector' do
        result = subject.extract(url, 'nav.primary a')
        
        expect(result).to include('https://example.com/nav1')
        expect(result).to include('https://example.com/nav2')
        expect(result).not_to include('https://example.com/sidebar1')
        expect(result).not_to include('https://example.com/footer1')
      end

      it 'works with descendant selectors' do
        result = subject.extract(url, 'footer nav a')
        
        expect(result).to include('https://example.com/footer1')
        expect(result).not_to include('https://example.com/nav1')
        expect(result).not_to include('https://example.com/nav2')
        expect(result).not_to include('https://example.com/sidebar1')
      end
    end

    context 'when selector returns no elements' do
      let(:html_without_matching_elements) do
        <<~HTML
          <html>
          <body>
            <p>No links here</p>
          </body>
          </html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(html_without_matching_elements)
      end

      it 'prints warning and returns empty array' do
        result = subject.extract(url, 'nav a')
        expect(result).to eq([])
      end
    end

    context 'when selector matches elements but no URLs found' do
      let(:html_without_urls) do
        <<~HTML
          <html>
          <body>
            <nav>
              <span>Just text, no links</span>
            </nav>
          </body>
          </html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(html_without_urls)
      end

      it 'prints warning and returns empty array' do
        result = subject.extract(url, 'nav')
        expect(result).to eq([])
      end
    end

    context 'with different source domains' do
      let(:html_with_links) do
        <<~HTML
          <html>
          <body>
            <nav>
              <a href="/page1">Page 1</a>
              <a href="https://subdomain.example.com/page">Subdomain</a>
              <a href="https://different.com/page">Different domain</a>
            </nav>
          </body>
          </html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).with(source_url).and_return(html_with_links)
      end

      context 'from main domain' do
        let(:source_url) { 'https://example.com/page' }

        it 'includes URLs from same domain only' do
          result = subject.extract(source_url, 'nav a')
          
          expect(result).to include('https://example.com/page1')
          expect(result).not_to include('https://subdomain.example.com/page')
          expect(result).not_to include('https://different.com/page')
        end
      end

      context 'from subdomain' do
        let(:source_url) { 'https://subdomain.example.com/page' }

        it 'includes URLs from same subdomain only' do
          result = subject.extract(source_url, 'nav a')
          
          expect(result).to include('https://subdomain.example.com/page1')
          expect(result).to include('https://subdomain.example.com/page')
          expect(result).not_to include('https://different.com/page')
        end
      end
    end

    context 'when HTTP client raises error' do
      before do
        allow(http_client).to receive(:fetch).and_raise(StandardError.new('Network error'))
      end

      it 're-raises the error' do
        expect { subject.extract(url, selector) }
          .to raise_error(StandardError, 'Network error')
      end
    end

    context 'with malformed HTML' do
      let(:malformed_html) do
        '<html><body><nav><a href="/page1">Unclosed link<a href="/page2">Page 2</a></nav></body></html>'
      end

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(malformed_html)
      end

      it 'handles malformed HTML gracefully' do
        result = subject.extract(url, 'nav a')
        
        # Nokogiri should still be able to parse and extract URLs
        expect(result).to be_an(Array)
        expect(result).to include('https://example.com/page1')
        expect(result).to include('https://example.com/page2')
      end
    end

    context 'with empty HTML' do
      before do
        allow(http_client).to receive(:fetch).with(url).and_return('')
      end

      it 'handles empty HTML gracefully' do
        result = subject.extract(url, selector)
        expect(result).to eq([])
      end
    end

    context 'with URLs containing special characters' do
      let(:html_with_special_chars) do
        <<~HTML
          <html>
          <body>
            <nav>
              <a href="/path with spaces">Spaces</a>
              <a href="/path-with-dashes">Dashes</a>
              <a href="/path_with_underscores">Underscores</a>
              <a href="/path%20encoded">Encoded</a>
              <a href="/caf%C3%A9">Unicode encoded</a>
            </nav>
          </body>
          </html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).with(url).and_return(html_with_special_chars)
      end

      it 'preserves special characters in URLs' do
        result = subject.extract(url, 'nav a')
        
        expect(result).to include('https://example.com/path with spaces')
        expect(result).to include('https://example.com/path-with-dashes')
        expect(result).to include('https://example.com/path_with_underscores')
        expect(result).to include('https://example.com/path%20encoded')
        expect(result).to include('https://example.com/caf%C3%A9')
      end
    end
  end
end