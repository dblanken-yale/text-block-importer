# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'Full Text Block Importer Workflow', type: :integration do
  include WebMock::API

  let(:temp_dir) { create_temp_directory }
  let(:template_path) { fixture_path('test_template.yml') }
  let(:config) { mock_config }
  
  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    WebMock.reset!
  end

  before do
    WebMock.enable!
  end

  describe 'Single page scraping and YAML generation' do
    let(:page_url) { 'https://example.com/test-page' }
    let(:page_html) { read_fixture('sample_page.html') }
    let(:selector) { '.content-main' }

    before do
      stub_request(:get, page_url).to_return(body: page_html, status: 200)
    end

    it 'scrapes content and generates valid YAML' do
      # Create scraper and generator
      scraper = TextBlockImporter::Scraper.new(config)
      generator = TextBlockImporter::YamlGenerator.new(template_path, config)

      # Scrape content
      scraped_content = scraper.scrape(page_url, selector)
      expect(scraped_content.title).to eq('Sample Test Page')
      expect(scraped_content.content).to include('Main Content Section')

      # Generate YAML
      yaml_content = generator.generate(scraped_content)
      expect(yaml_content).to include("title: 'Sample Test Page'")
      expect(yaml_content).to include('Main Content Section')

      # Verify YAML is valid
      parsed = YAML.safe_load(yaml_content)
      expect(parsed['entity_type']).to eq('node')
      expect(parsed['bundle']).to eq('page')
      expect_valid_uuid(parsed['uuid'])
    end

    it 'handles relative URLs when use_domains option is enabled' do
      html_with_relative = <<~HTML
        <html>
        <head><title>Relative URL Test</title></head>
        <body>
          <h1>Test Page</h1>
          <div class="content-main">
            <p>Content with <a href="/relative-link">relative link</a></p>
            <img src="/images/photo.jpg" alt="Photo">
          </div>
        </body>
        </html>
      HTML

      stub_request(:get, page_url).to_return(body: html_with_relative, status: 200)

      scraper = TextBlockImporter::Scraper.new(config)
      generator = TextBlockImporter::YamlGenerator.new(template_path, config)

      scraped_content = scraper.scrape(page_url, selector)
      yaml_content = generator.generate(scraped_content, use_domains: true)

      expect(yaml_content).to include('https://example.com/relative-link')
      expect(yaml_content).to include('https://example.com/images/photo.jpg')
    end

    it 'saves generated YAML to file' do
      scraper = TextBlockImporter::Scraper.new(config)
      generator = TextBlockImporter::YamlGenerator.new(template_path, config)
      output_path = File.join(temp_dir, 'output.yml')

      scraped_content = scraper.scrape(page_url, selector)
      yaml_content = generator.generate(scraped_content)
      generator.save(yaml_content, output_path)

      expect(File.exist?(output_path)).to be true
      saved_content = File.read(output_path)
      expect(saved_content).to eq(yaml_content)

      # Verify saved file is valid YAML
      parsed = YAML.safe_load(saved_content)
      expect(parsed).to be_a(Hash)
    end
  end

  describe 'URL extraction workflow' do
    let(:page_url) { 'https://example.com/links-page' }
    let(:links_html) do
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
      stub_request(:get, page_url).to_return(body: links_html, status: 200)
    end

    it 'extracts URLs from page using CSS selector' do
      extractor = TextBlockImporter::UrlExtractor.new

      urls = extractor.extract(page_url, 'nav a')

      expect(urls).to include('https://example.com/page1')
      expect(urls).to include('https://example.com/page2')
      expect(urls).to include('https://example.com/page3')
      expect(urls).not_to include('https://external.com/page')
    end
  end

  describe 'Sitemap parsing workflow' do
    let(:sitemap_url) { 'https://example.com/sitemap.xml' }
    let(:sitemap_xml) { read_fixture('sample_sitemap.xml') }

    before do
      stub_request(:get, sitemap_url).to_return(body: sitemap_xml, status: 200)
    end

    it 'parses sitemap and extracts all URLs' do
      parser = TextBlockImporter::SitemapParser.new(config)

      urls = parser.parse(sitemap_url)

      expect(urls).to include('https://example.com/')
      expect(urls).to include('https://example.com/about')
      expect(urls).to include('https://example.com/services')
      expect(urls).to include('https://example.com/contact')
    end

    context 'with nested sitemaps' do
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
      
      let(:categories_sitemap_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>https://example.com/category1</loc></url>
            <url><loc>https://example.com/category2</loc></url>
          </urlset>
        XML
      end

      before do
        stub_request(:get, sitemap_url).to_return(body: sitemap_index_xml, status: 200)
        stub_request(:get, 'https://example.com/sitemap-pages.xml').to_return(body: pages_sitemap_xml, status: 200)
        stub_request(:get, 'https://example.com/sitemap-posts.xml').to_return(body: posts_sitemap_xml, status: 200)
        stub_request(:get, 'https://example.com/sitemap-categories.xml').to_return(body: categories_sitemap_xml, status: 200)
      end

      it 'recursively parses nested sitemaps' do
        recursive_config = mock_config('sitemap' => { 'recursive' => true })
        parser = TextBlockImporter::SitemapParser.new(recursive_config)

        urls = parser.parse(sitemap_url)

        expect(urls).to include('https://example.com/page1')
        expect(urls).to include('https://example.com/page2')
        expect(urls.length).to be >= 6 # 2 URLs × 3 nested sitemaps
      end
    end
  end

  describe 'End-to-end batch processing simulation' do
    let(:sitemap_url) { 'https://example.com/sitemap.xml' }
    let(:sitemap_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url><loc>https://example.com/page1</loc></url>
          <url><loc>https://example.com/page2</loc></url>
        </urlset>
      XML
    end

    let(:page1_html) do
      <<~HTML
        <html>
        <head><title>Page 1 Title</title></head>
        <body>
          <h1>Page 1 Title</h1>
          <div class="content"><p>Content for page 1</p></div>
        </body>
        </html>
      HTML
    end

    let(:page2_html) do
      <<~HTML
        <html>
        <head><title>Page 2 Title</title></head>
        <body>
          <h1>Page 2 Title</h1>
          <div class="content"><p>Content for page 2</p></div>
        </body>
        </html>
      HTML
    end

    before do
      stub_request(:get, sitemap_url).to_return(body: sitemap_xml, status: 200)
      stub_request(:get, 'https://example.com/page1').to_return(body: page1_html, status: 200)
      stub_request(:get, 'https://example.com/page2').to_return(body: page2_html, status: 200)
    end

    it 'processes complete workflow from sitemap to YAML files' do
      # Step 1: Parse sitemap
      parser = TextBlockImporter::SitemapParser.new(config)
      urls = parser.parse(sitemap_url)

      expect(urls.length).to eq(2)

      # Step 2: Process each URL
      scraper = TextBlockImporter::Scraper.new(config)
      generator = TextBlockImporter::YamlGenerator.new(template_path, config)

      results = []
      urls.each_with_index do |url, index|
        scraped_content = scraper.scrape(url, '.content')
        yaml_content = generator.generate(scraped_content)
        
        output_path = File.join(temp_dir, "node-#{index + 1}.output.yml")
        generator.save(yaml_content, output_path)
        
        results << {
          url: url,
          title: scraped_content.title,
          output_path: output_path
        }
      end

      # Step 3: Verify results
      expect(results.length).to eq(2)

      # Verify first page
      page1_result = results.find { |r| r[:url] == 'https://example.com/page1' }
      expect(page1_result[:title]).to eq('Page 1 Title')
      expect(File.exist?(page1_result[:output_path])).to be true

      page1_yaml = YAML.safe_load(File.read(page1_result[:output_path]))
      expect(page1_yaml['base_fields']['title']).to eq('Page 1 Title')
      expect(page1_yaml['custom_fields']['field_external_source'].first['uri']).to eq('https://example.com/page1')

      # Verify second page
      page2_result = results.find { |r| r[:url] == 'https://example.com/page2' }
      expect(page2_result[:title]).to eq('Page 2 Title')
      expect(File.exist?(page2_result[:output_path])).to be true

      page2_yaml = YAML.safe_load(File.read(page2_result[:output_path]))
      expect(page2_yaml['base_fields']['title']).to eq('Page 2 Title')
      expect(page2_yaml['custom_fields']['field_external_source'].first['uri']).to eq('https://example.com/page2')

      # Verify unique UUIDs
      expect(page1_yaml['uuid']).not_to eq(page2_yaml['uuid'])
    end
  end

  describe 'Error handling in full workflow' do
    let(:page_url) { 'https://example.com/error-page' }

    context 'when HTTP request fails' do
      before do
        stub_request(:get, page_url).to_raise(SocketError.new('Host not found'))
      end

      it 'raises appropriate error from scraper' do
        scraper = TextBlockImporter::Scraper.new(config)

        expect { scraper.scrape(page_url, '.content') }
          .to raise_error(TextBlockImporter::SelectorError, /Failed to scrape/)
      end
    end

    context 'when selector finds no content' do
      let(:empty_html) { read_fixture('empty_page.html') }

      before do
        stub_request(:get, page_url).to_return(body: empty_html, status: 200)
      end

      it 'generates YAML with empty content but continues processing' do
        config_warn = mock_config('processing' => { 'warn_empty_content' => true })
        scraper = TextBlockImporter::Scraper.new(config_warn)
        generator = TextBlockImporter::YamlGenerator.new(template_path, config_warn)

        scraped_content = scraper.scrape(page_url, '.content-main')
        expect(scraped_content.content).to eq('')

        yaml_content = generator.generate(scraped_content)
        parsed = YAML.safe_load(yaml_content)
        
        # Should still generate valid YAML structure
        expect(parsed['entity_type']).to eq('node')
        expect(parsed['bundle']).to eq('page')
        
        # But content should be empty
        text_field = parsed.dig('custom_fields', 'layout_builder__layout', 'blocks', 0, 'custom_fields', 'field_text', 0, 'value')
        expect(text_field).to eq('')
      end
    end

    context 'when template file is missing' do
      let(:missing_template) { File.join(temp_dir, 'missing.yml') }

      it 'raises error during generator initialization' do
        expect { TextBlockImporter::YamlGenerator.new(missing_template, config) }
          .to raise_error(Errno::ENOENT)
      end
    end

    context 'when output directory cannot be created' do
      it 'raises error during file save' do
        scraper = TextBlockImporter::Scraper.new(config)
        generator = TextBlockImporter::YamlGenerator.new(template_path, config)

        stub_request(:get, page_url).to_return(body: read_fixture('sample_page.html'), status: 200)

        scraped_content = scraper.scrape(page_url, '.content-main')
        yaml_content = generator.generate(scraped_content)

        # Try to save to a path that cannot be created (parent is file, not directory)
        invalid_path = File.join(template_path, 'cannot', 'create', 'this.yml')

        expect { generator.save(yaml_content, invalid_path) }
          .to raise_error(Errno::ENOTDIR)
      end
    end
  end

  describe 'Configuration integration' do
    let(:page_url) { 'https://example.com/config-test' }
    let(:test_html) do
      <<~HTML
        <html>
        <head><title>Config Test</title></head>
        <body>
          <h2 class="custom-title">Custom Title</h2>
          <div class="content">
            Content with 'quotes' and
            newlines
          </div>
        </body>
        </html>
      HTML
    end

    before do
      stub_request(:get, page_url).to_return(body: test_html, status: 200)
    end

    it 'respects custom configuration settings' do
      custom_config = mock_config(
        'processing' => {
          'strip_newlines' => false,
          'encode_quotes' => false
        },
        'templates' => {
          'tokens' => {
            'name_selector' => 'h2.custom-title',
            'encode_title' => false
          }
        }
      )

      scraper = TextBlockImporter::Scraper.new(custom_config)
      generator = TextBlockImporter::YamlGenerator.new(template_path, custom_config)

      scraped_content = scraper.scrape(page_url, '.content')

      # Should use custom title selector
      expect(scraped_content.title).to eq('Custom Title')

      # Should preserve newlines and quotes
      expect(scraped_content.content).to include("\n")
      expect(scraped_content.content).to include("'")
      expect(scraped_content.content).not_to include("&#39;")

      yaml_content = generator.generate(scraped_content)
      
      # Title should not be encoded
      expect(yaml_content).to include("title: 'Custom Title'")
      expect(yaml_content).not_to include("&#39;")
    end
  end

  describe 'Performance and memory considerations' do
    let(:large_sitemap_url) { 'https://example.com/large-sitemap.xml' }
    let(:page_url) { 'https://example.com/large-page' }

    it 'handles large sitemaps efficiently' do
      # Generate sitemap with many URLs
      urls = (1..100).map { |i| "https://example.com/page#{i}" }
      large_sitemap = sample_sitemap_xml(urls)

      stub_request(:get, large_sitemap_url).to_return(body: large_sitemap, status: 200)

      parser = TextBlockImporter::SitemapParser.new(config)

      start_time = Time.now
      parsed_urls = parser.parse(large_sitemap_url)
      end_time = Time.now

      expect(parsed_urls.length).to eq(100)
      expect(end_time - start_time).to be < 5 # Should complete within 5 seconds
    end

    it 'handles large HTML documents efficiently' do
      # Generate large HTML content
      large_content = '<p>' + ('Sample content. ' * 10000) + '</p>'
      large_html = <<~HTML
        <html>
        <head><title>Large Page</title></head>
        <body>
          <h1>Large Page</h1>
          <div class="content">#{large_content}</div>
        </body>
        </html>
      HTML

      stub_request(:get, page_url).to_return(body: large_html, status: 200)

      scraper = TextBlockImporter::Scraper.new(config)
      generator = TextBlockImporter::YamlGenerator.new(template_path, config)

      start_time = Time.now
      scraped_content = scraper.scrape(page_url, '.content')
      yaml_content = generator.generate(scraped_content)
      end_time = Time.now

      expect(scraped_content.content.length).to be > 100000
      expect(yaml_content.length).to be > 100000
      expect(end_time - start_time).to be < 10 # Should complete within 10 seconds
    end
  end
end