# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TextBlockImporter::Scraper do
  let(:config) { mock_config }
  let(:logger) { double('Logger', debug: nil, warn: nil, info: nil) }
  let(:http_client) { instance_double(TextBlockImporter::HttpClient) }
  
  subject { described_class.new(config, logger) }

  before do
    allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)
  end

  describe '#initialize' do
    it 'creates a new instance with config and logger' do
      scraper = described_class.new(config, logger)
      expect(scraper).to be_an_instance_of(described_class)
    end

    it 'works without logger' do
      scraper = described_class.new(config)
      expect(scraper).to be_an_instance_of(described_class)
    end

    it 'creates HTTP client with provided config' do
      expect(TextBlockImporter::HttpClient).to receive(:new).with(config, logger)
      described_class.new(config, logger)
    end
  end

  describe '#scrape' do
    let(:url) { 'https://example.com/test-page' }
    let(:selector) { '.content-main' }
    let(:html_content) { read_fixture('sample_page.html') }

    before do
      allow(http_client).to receive(:fetch).with(url).and_return(html_content)
    end

    context 'with valid selector' do
      it 'returns ScrapedContent object' do
        result = subject.scrape(url, selector)
        
        expect(result).to be_a(TextBlockImporter::ScrapedContent)
        expect(result.url).to eq(url)
        expect(result.domain).to eq('example.com')
        expect(result.title).to eq('Sample Test Page')
        expect(result.content).to include('Main Content Section')
      end

      it 'extracts content using CSS selector' do
        result = subject.scrape(url, selector)
        
        expect(result.content).to include('This is a sample paragraph')
        expect(result.content).to include('<strong>bold text</strong>')
        expect(result.content).not_to include('Sidebar Content')
      end

      it 'extracts title from h1 element by default' do
        result = subject.scrape(url, selector)
        expect(result.title).to eq('Sample Test Page')
      end

      it 'uses custom name selector from config' do
        custom_config = mock_config(
          'templates' => { 'tokens' => { 'name_selector' => 'title' } }
        )
        scraper = described_class.new(custom_config, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        result = scraper.scrape(url, selector)
        expect(result.title).to eq('Sample Test Page')
      end
    end

    context 'with content processing options' do
      let(:html_with_newlines) do
        <<~HTML
          <html><body>
          <h1>Test Title</h1>
          <div class="content">
          Line 1
          Line 2
          Line 3
          </div>
          </body></html>
        HTML
      end

      before do
        allow(http_client).to receive(:fetch).and_return(html_with_newlines)
      end

      it 'strips newlines when configured' do
        config_with_strip = mock_config(
          'processing' => { 'strip_newlines' => true }
        )
        scraper = described_class.new(config_with_strip, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        result = scraper.scrape(url, '.content')
        expect(result.content).not_to include("\n")
      end

      it 'preserves newlines when configured' do
        config_no_strip = mock_config(
          'processing' => { 'strip_newlines' => false }
        )
        scraper = described_class.new(config_no_strip, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        result = scraper.scrape(url, '.content')
        expect(result.content).to include("\n")
      end
    end

    context 'with quote encoding' do
      let(:html_with_quotes) { read_fixture('page_with_quotes.html') }

      before do
        allow(http_client).to receive(:fetch).and_return(html_with_quotes)
      end

      it 'encodes single quotes in content when configured' do
        config_encode = mock_config(
          'processing' => { 'encode_quotes' => true }
        )
        scraper = described_class.new(config_encode, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        result = scraper.scrape(url, '.content-main')
        expect(result.content).to include('&#39;')
        expect(result.content).not_to include("'")
      end

      it 'preserves single quotes when encoding disabled' do
        config_no_encode = mock_config(
          'processing' => { 'encode_quotes' => false }
        )
        scraper = described_class.new(config_no_encode, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        result = scraper.scrape(url, '.content-main')
        expect(result.content).to include("'")
      end

      it 'encodes single quotes in title when configured' do
        config_encode_title = mock_config(
          'templates' => { 'tokens' => { 'encode_title' => true } }
        )
        scraper = described_class.new(config_encode_title, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        result = scraper.scrape(url, '.content-main')
        expect(result.title).to include('&#39;')
        expect(result.title).not_to include("'")
      end
    end

    context 'with empty content' do
      let(:empty_html) { read_fixture('empty_page.html') }

      before do
        allow(http_client).to receive(:fetch).and_return(empty_html)
      end

      it 'returns empty string for content' do
        result = subject.scrape(url, '.content-main')
        expect(result.content).to eq('')
      end

      it 'logs warning when content is empty and warnings enabled' do
        config_warn = mock_config(
          'processing' => { 'warn_empty_content' => true }
        )
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)
        scraper = described_class.new(config_warn, logger)
        
        result = nil
        expect { result = scraper.scrape(url, '.content-main') }.to output(/Warning:/).to_stderr
        
        expect(result.content).to eq('')
      end

      it 'does not log warning when warnings disabled' do
        config_no_warn = mock_config(
          'processing' => { 'warn_empty_content' => false }
        )
        scraper = described_class.new(config_no_warn, logger)
        allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)

        expect(logger).not_to receive(:warn)
        scraper.scrape(url, '.content-main')
      end
    end

    context 'with invalid selector' do
      it 'returns empty content for non-existent selector' do
        result = subject.scrape(url, '.non-existent-selector')
        expect(result.content).to eq('')
      end
    end

    context 'when HTTP client raises error' do
      before do
        allow(http_client).to receive(:fetch).and_raise(StandardError.new('Network error'))
      end

      it 'raises SelectorError with meaningful message' do
        expect { subject.scrape(url, selector) }.to raise_error(
          TextBlockImporter::SelectorError,
          /Failed to scrape #{Regexp.escape(url)} with selector '#{Regexp.escape(selector)}': Network error/
        )
      end
    end

    context 'with malformed HTML' do
      let(:malformed_html) { '<html><head><title>Test</title><body><div class="content">Unclosed div</body></html>' }

      before do
        allow(http_client).to receive(:fetch).and_return(malformed_html)
      end

      it 'handles malformed HTML gracefully' do
        expect { subject.scrape(url, '.content') }.not_to raise_error
        result = subject.scrape(url, '.content')
        expect(result.content).to include('Unclosed div')
      end
    end
  end
end

RSpec.describe TextBlockImporter::ScrapedContent do
  let(:content) { '<p>Sample content with <a href="/relative">relative link</a></p>' }
  let(:title) { 'Test Title' }
  let(:url) { 'https://example.com/page' }
  let(:domain) { 'example.com' }

  subject do
    described_class.new(
      content: content,
      title: title,
      url: url,
      domain: domain
    )
  end

  describe '#initialize' do
    it 'sets all attributes correctly' do
      expect(subject.content).to eq(content)
      expect(subject.title).to eq(title)
      expect(subject.url).to eq(url)
      expect(subject.domain).to eq(domain)
    end
  end

  describe '#process_relative_urls' do
    context 'with domain present' do
      it 'converts relative href URLs to absolute' do
        result = subject.process_relative_urls
        expect(result).to include('href="https://example.com/relative"')
        expect(result).not_to include('href="/relative"')
      end

      it 'converts relative src URLs to absolute' do
        content_with_images = '<img src="/images/photo.jpg" alt="Photo">'
        scraped = described_class.new(
          content: content_with_images,
          title: title,
          url: url,
          domain: domain
        )

        result = scraped.process_relative_urls
        expect(result).to include('src="https://example.com/images/photo.jpg"')
        expect(result).not_to include('src="/images/photo.jpg"')
      end

      it 'preserves absolute URLs' do
        content_with_absolute = '<a href="https://other.com/page">External</a>'
        scraped = described_class.new(
          content: content_with_absolute,
          title: title,
          url: url,
          domain: domain
        )

        result = scraped.process_relative_urls
        expect(result).to include('href="https://other.com/page"')
      end

      it 'handles mixed relative and absolute URLs' do
        mixed_content = '<a href="/page1">Internal</a> <a href="https://external.com">External</a>'
        scraped = described_class.new(
          content: mixed_content,
          title: title,
          url: url,
          domain: domain
        )

        result = scraped.process_relative_urls
        expect(result).to include('href="https://example.com/page1"')
        expect(result).to include('href="https://external.com"')
      end
    end

    context 'without domain' do
      subject do
        described_class.new(
          content: content,
          title: title,
          url: url,
          domain: nil
        )
      end

      it 'returns original content unchanged' do
        result = subject.process_relative_urls
        expect(result).to eq(content)
      end
    end

    context 'with empty content' do
      subject do
        described_class.new(
          content: '',
          title: title,
          url: url,
          domain: domain
        )
      end

      it 'returns empty string' do
        result = subject.process_relative_urls
        expect(result).to eq('')
      end
    end
  end
end