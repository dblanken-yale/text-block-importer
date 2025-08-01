# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TextBlockImporter::SitemapParser do
  let(:config) { mock_config }
  let(:logger) { double('Logger', debug: nil, warn: nil, info: nil, error: nil) }
  let(:http_client) { instance_double(TextBlockImporter::HttpClient) }

  subject { described_class.new(config, logger) }

  before do
    allow(TextBlockImporter::HttpClient).to receive(:new).and_return(http_client)
  end

  describe '#initialize' do
    it 'creates a new instance with config and logger' do
      parser = described_class.new(config, logger)
      expect(parser).to be_an_instance_of(described_class)
    end

    it 'works without logger' do
      parser = described_class.new(config)
      expect(parser).to be_an_instance_of(described_class)
    end

    it 'creates HTTP client with provided config' do
      expect(TextBlockImporter::HttpClient).to receive(:new).with(config, logger)
      described_class.new(config, logger)
    end
  end

  describe '#parse' do
    let(:sitemap_url) { 'https://example.com/sitemap.xml' }

    context 'with single sitemap (non-recursive)' do
      let(:sitemap_xml) { read_fixture('sample_sitemap.xml') }
      let(:config_non_recursive) do
        mock_config('sitemap' => { 'recursive' => false })
      end

      before do
        allow(http_client).to receive(:fetch).with(sitemap_url).and_return(sitemap_xml)
      end

      subject { described_class.new(config_non_recursive, logger) }

      it 'extracts URLs from single sitemap' do
        result = subject.parse(sitemap_url)

        expect(result).to be_an(Array)
        expect(result).to include('https://example.com/')
        expect(result).to include('https://example.com/about')
        expect(result).to include('https://example.com/services')
        expect(result).to include('https://example.com/contact')
      end

      it 'logs info about parsing' do
        expect(logger).to receive(:info).with(/Starting sitemap parsing/)
        expect(logger).to receive(:info).with(/Found \d+ total URLs/)
        
        subject.parse(sitemap_url)
      end

      it 'returns unique URLs only' do
        duplicate_sitemap = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>https://example.com/page1</loc></url>
            <url><loc>https://example.com/page2</loc></url>
            <url><loc>https://example.com/page1</loc></url>
          </urlset>
        XML

        allow(http_client).to receive(:fetch).with(sitemap_url).and_return(duplicate_sitemap)

        result = subject.parse(sitemap_url)
        expect(result.length).to eq(2)
        expect(result.count('https://example.com/page1')).to eq(1)
      end
    end

    context 'with recursive sitemap parsing' do
      let(:config_recursive) do
        mock_config('sitemap' => { 'recursive' => true, 'max_depth' => 3 })
      end

      subject { described_class.new(config_recursive, logger) }

      context 'with sitemap index' do
        let(:sitemap_index_xml) { read_fixture('nested_sitemap_index.xml') }
        let(:pages_sitemap_xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/page1</loc></url>
              <url><loc>https://example.com/page2</loc></url>
            </urlset>
          XML
        end
        let(:posts_sitemap_xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/post1</loc></url>
              <url><loc>https://example.com/post2</loc></url>
            </urlset>
          XML
        end

        before do
          allow(http_client).to receive(:fetch).with(sitemap_url).and_return(sitemap_index_xml)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-pages.xml').and_return(pages_sitemap_xml)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-posts.xml').and_return(posts_sitemap_xml)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-categories.xml').and_return(pages_sitemap_xml)
        end

        it 'recursively parses nested sitemaps' do
          result = subject.parse(sitemap_url)

          expect(result).to include('https://example.com/page1')
          expect(result).to include('https://example.com/page2')
          expect(result).to include('https://example.com/post1')
          expect(result).to include('https://example.com/post2')
        end

        it 'logs information about nested sitemaps' do
          expect(logger).to receive(:debug).with(/Detected nested sitemap/).at_least(:once)
          expect(logger).to receive(:info).with(/Found \d+ page URLs and \d+ nested sitemaps/).at_least(:once)

          subject.parse(sitemap_url)
        end
      end

      context 'with paginated sitemaps' do
        let(:main_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/sitemap.xml?page=1</loc></url>
              <url><loc>https://example.com/sitemap.xml?page=2</loc></url>
              <url><loc>https://example.com/page1</loc></url>
            </urlset>
          XML
        end
        let(:page1_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/page2</loc></url>
              <url><loc>https://example.com/page3</loc></url>
            </urlset>
          XML
        end
        let(:page2_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/page4</loc></url>
            </urlset>
          XML
        end

        before do
          allow(http_client).to receive(:fetch).with(sitemap_url).and_return(main_sitemap)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap.xml?page=1').and_return(page1_sitemap)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap.xml?page=2').and_return(page2_sitemap)
        end

        it 'handles paginated sitemaps correctly' do
          result = subject.parse(sitemap_url)

          expect(result).to include('https://example.com/page1')
          expect(result).to include('https://example.com/page2')
          expect(result).to include('https://example.com/page3')
          expect(result).to include('https://example.com/page4')
        end

        it 'recognizes paginated sitemaps as nested sitemaps' do
          expect(logger).to receive(:debug).with(/Detected paginated sitemap/).at_least(:once)

          subject.parse(sitemap_url)
        end
      end

      context 'with maximum depth limit' do
        let(:config_shallow) do
          mock_config('sitemap' => { 'recursive' => true, 'max_depth' => 1 })
        end

        subject { described_class.new(config_shallow, logger) }

        let(:deep_nested_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/sitemap-level2.xml</loc></url>
              <url><loc>https://example.com/page1</loc></url>
            </urlset>
          XML
        end
        let(:level2_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/sitemap-level3.xml</loc></url>
              <url><loc>https://example.com/page2</loc></url>
            </urlset>
          XML
        end

        before do
          allow(http_client).to receive(:fetch).with(sitemap_url).and_return(deep_nested_sitemap)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-level2.xml').and_return(level2_sitemap)
        end

        it 'respects maximum depth limit' do
          result = subject.parse(sitemap_url)

          expect(result).to include('https://example.com/page1')
          expect(result).to include('https://example.com/page2')
          # Level 3 should not be processed due to depth limit
          expect(http_client).not_to have_received(:fetch).with('https://example.com/sitemap-level3.xml')
        end
      end

      context 'with same domain only restriction' do
        let(:config_same_domain) do
          mock_config('sitemap' => { 'recursive' => true, 'same_domain_only' => true })
        end

        subject { described_class.new(config_same_domain, logger) }

        let(:cross_domain_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/sitemap-same.xml</loc></url>
              <url><loc>https://other.com/sitemap-external.xml</loc></url>
              <url><loc>https://example.com/page1</loc></url>
            </urlset>
          XML
        end
        let(:same_domain_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/page2</loc></url>
            </urlset>
          XML
        end

        before do
          allow(http_client).to receive(:fetch).with(sitemap_url).and_return(cross_domain_sitemap)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-same.xml').and_return(same_domain_sitemap)
        end

        it 'skips cross-domain sitemaps' do
          expect(logger).to receive(:debug).with(/Skipping cross-domain sitemap/)

          result = subject.parse(sitemap_url)

          expect(result).to include('https://example.com/page1')
          expect(result).to include('https://example.com/page2')
          expect(http_client).not_to have_received(:fetch).with('https://other.com/sitemap-external.xml')
        end
      end

      context 'when nested sitemap fails to parse' do
        let(:failing_sitemap_index) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/sitemap-good.xml</loc></url>
              <url><loc>https://example.com/sitemap-bad.xml</loc></url>
              <url><loc>https://example.com/page1</loc></url>
            </urlset>
          XML
        end
        let(:good_sitemap) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/page2</loc></url>
            </urlset>
          XML
        end

        before do
          allow(http_client).to receive(:fetch).with(sitemap_url).and_return(failing_sitemap_index)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-good.xml').and_return(good_sitemap)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-bad.xml').and_raise(StandardError.new('Network error'))
        end

        it 'continues processing other sitemaps when one fails' do
          expect(logger).to receive(:warn).with(/Failed to parse nested sitemap/)

          result = subject.parse(sitemap_url)

          expect(result).to include('https://example.com/page1')
          expect(result).to include('https://example.com/page2')
        end
      end
    end

    context 'with duplicate sitemap processing prevention' do
      let(:config_recursive) do
        mock_config('sitemap' => { 'recursive' => true })
      end

      subject { described_class.new(config_recursive, logger) }

      let(:circular_sitemap) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>#{sitemap_url}</loc></url>
            <url><loc>https://example.com/page1</loc></url>
          </urlset>
        XML
      end

      before do
        allow(http_client).to receive(:fetch).with(sitemap_url).and_return(circular_sitemap)
      end

      it 'prevents infinite loops by tracking processed sitemaps' do
        result = subject.parse(sitemap_url)

        expect(result).to include('https://example.com/page1')
        expect(http_client).to have_received(:fetch).with(sitemap_url).once
      end
    end

    context 'when sitemap is empty or has no URLs' do
      let(:empty_sitemap) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          </urlset>
        XML
      end

      before do
        allow(http_client).to receive(:fetch).with(sitemap_url).and_return(empty_sitemap)
      end

      it 'raises SelectorError for empty sitemap' do
        expect(logger).to receive(:error).with(/No URLs found in sitemap/)

        expect { subject.parse(sitemap_url) }
          .to raise_error(TextBlockImporter::SelectorError, /No URLs found in sitemap/)
      end
    end

    context 'when HTTP client raises error' do
      before do
        allow(http_client).to receive(:fetch).and_raise(StandardError.new('Network error'))
      end

      it 'raises SelectorError with network error details' do
        expect(logger).to receive(:error).with(/Error parsing sitemap/)

        expect { subject.parse(sitemap_url) }
          .to raise_error(TextBlockImporter::SelectorError, /Error parsing sitemap: Network error/)
      end
    end

    context 'with malformed XML' do
      let(:malformed_xml) { '<urlset><invalid>xml</structure>' }

      before do
        allow(http_client).to receive(:fetch).with(sitemap_url).and_return(malformed_xml)
      end

      it 'handles malformed XML gracefully' do
        # Should return empty array since no valid <loc> tags found
        expect(logger).to receive(:error).at_least(:once)
        expect { subject.parse(sitemap_url) }.to raise_error(TextBlockImporter::SelectorError)
      end
    end

    context 'with complex sitemap structures' do
      let(:config_recursive) do
        mock_config('sitemap' => { 'recursive' => true })
      end

      subject { described_class.new(config_recursive, logger) }

      let(:complex_sitemap) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url>
              <loc>https://example.com/page1</loc>
              <lastmod>2024-01-01T12:00:00+00:00</lastmod>
              <changefreq>daily</changefreq>
              <priority>1.0</priority>
            </url>
            <url>
              <loc>https://example.com/sitemap-posts.xml</loc>
              <lastmod>2024-01-01T12:00:00+00:00</lastmod>
            </url>
            <url>
              <loc>https://example.com/page2</loc>
              <changefreq>weekly</changefreq>
            </url>
          </urlset>
        XML
      end
      let(:posts_sitemap) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>https://example.com/post1</loc></url>
          </urlset>
        XML
      end

      before do
        allow(http_client).to receive(:fetch).with(sitemap_url).and_return(complex_sitemap)
        allow(http_client).to receive(:fetch).with('https://example.com/sitemap-posts.xml').and_return(posts_sitemap)
      end

      it 'extracts URLs from complex sitemap structures' do
        result = subject.parse(sitemap_url)

        expect(result).to include('https://example.com/page1')
        expect(result).to include('https://example.com/page2')
        expect(result).to include('https://example.com/post1')
        expect(result.length).to eq(3)
      end
    end
  end

  describe 'private methods behavior' do
    let(:config_recursive) do
      mock_config('sitemap' => { 'recursive' => true })
    end

    subject { described_class.new(config_recursive, logger) }

    describe 'nested sitemap detection' do
      context 'with various URL formats' do
        it 'detects nested sitemaps correctly' do
          # These tests verify the private method behavior through public interface
          nested_sitemap_index = <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>https://example.com/sitemap-pages.xml</loc></url>
              <url><loc>https://example.com/sitemap.xml?page=1</loc></url>
              <url><loc>https://example.com/regular-page</loc></url>
              <url><loc>https://other.com/sitemap.xml</loc></url>
            </urlset>
          XML

          nested_sitemap = '<urlset><url><loc>https://example.com/nested-page</loc></url></urlset>'

          allow(http_client).to receive(:fetch).with('https://example.com/sitemap.xml').and_return(nested_sitemap_index)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap-pages.xml').and_return(nested_sitemap)
          allow(http_client).to receive(:fetch).with('https://example.com/sitemap.xml?page=1').and_return(nested_sitemap)

          result = subject.parse('https://example.com/sitemap.xml')

          # Should include regular page
          expect(result).to include('https://example.com/regular-page')
          # Should include nested sitemap content
          expect(result).to include('https://example.com/nested-page')
          # Should not fetch cross-domain sitemap when same_domain_only is true
          expect(http_client).not_to have_received(:fetch).with('https://other.com/sitemap.xml')
        end
      end
    end
  end
end