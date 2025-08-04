# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

module TestHelpers
  def fixture_path(filename)
    File.join(__dir__, '..', 'fixtures', filename)
  end

  def read_fixture(filename)
    File.read(fixture_path(filename))
  end

  def create_temp_file(content, extension = '.html')
    file = Tempfile.new(['test', extension])
    file.write(content)
    file.close
    file
  end

  def create_temp_directory
    Dir.mktmpdir('text_block_importer_test')
  end

  def mock_config(overrides = {})
    config_data = {
      'http' => {
        'timeout' => 30,
        'retries' => 3,
        'user_agent' => 'TestAgent/1.0',
        'follow_redirects' => true
      },
      'processing' => {
        'strip_newlines' => true,
        'encode_quotes' => true,
        'warn_empty_content' => true
      },
      'templates' => {
        'tokens' => {
          'name_selector' => 'h1',
          'encode_title' => true
        }
      },
      'output' => {
        'create_directories' => true,
        'filename_pattern' => 'node-{index}.output.yml'
      },
      'sitemap' => {
        'recursive' => true,
        'max_depth' => 3,
        'same_domain_only' => true
      }
    }

    merged_data = deep_merge(config_data, overrides)
    
    config = TextBlockImporter::Config.new
    config.instance_variable_set(:@data, merged_data)
    config
  end

  def stub_http_request(url, response_body, status_code = 200, headers = {})
    uri = URI.parse(url)
    response = Net::HTTPResponse.new('1.1', status_code.to_s, 'OK')
    allow(response).to receive(:body).and_return(response_body)
    headers.each { |key, value| allow(response).to receive(:[]).with(key).and_return(value) }
    
    allow(Net::HTTP).to receive(:get_response).with(uri).and_return(response)
    response
  end

  def sample_html_with_content(title = 'Test Page', content = '<p>Sample content</p>')
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>#{title}</title>
      </head>
      <body>
        <h1>#{title}</h1>
        <div class="content-main">
          #{content}
        </div>
        <nav>
          <a href="/page1">Page 1</a>
          <a href="/page2">Page 2</a>
          <a href="https://example.com/external">External</a>
        </nav>
      </body>
      </html>
    HTML
  end

  def sample_sitemap_xml(urls = ['https://example.com/page1', 'https://example.com/page2'])
    xml_urls = urls.map { |url| "  <url><loc>#{url}</loc></url>" }.join("\n")
    
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{xml_urls}
      </urlset>
    XML
  end

  def sample_sitemap_index_xml(sitemap_urls = ['https://example.com/sitemap1.xml'])
    xml_sitemaps = sitemap_urls.map { |url| "  <sitemap><loc>#{url}</loc></sitemap>" }.join("\n")
    
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{xml_sitemaps}
      </sitemapindex>
    XML
  end

  def expect_yaml_structure(yaml_content, expected_keys = [])
    parsed = YAML.safe_load(yaml_content)
    expect(parsed).to be_a(Hash)
    
    expected_keys.each do |key|
      expect(parsed).to have_key(key)
    end
    
    parsed
  end

  def expect_valid_uuid(uuid_string)
    uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
    expect(uuid_string).to match(uuid_pattern)
  end

  private

  def deep_merge(hash1, hash2)
    hash1.merge(hash2) do |_key, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        deep_merge(old_val, new_val)
      else
        new_val
      end
    end
  end
end