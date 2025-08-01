# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe TextBlockImporter::YamlGenerator do
  let(:template_path) { fixture_path('test_template.yml') }
  let(:config) { mock_config }
  let(:logger) { double('Logger', debug: nil, warn: nil, info: nil) }
  let(:scraped_content) do
    TextBlockImporter::ScrapedContent.new(
      content: '<p>Sample content for testing</p>',
      title: 'Test Page Title',
      url: 'https://example.com/test-page',
      domain: 'example.com'
    )
  end

  subject { described_class.new(template_path, config, logger) }

  describe '#initialize' do
    it 'creates a new instance with template path' do
      generator = described_class.new(template_path, config, logger)
      expect(generator).to be_an_instance_of(described_class)
    end

    it 'reads template content on initialization' do
      expect(File).to receive(:read).with(template_path).and_return('template content')
      described_class.new(template_path, config, logger)
    end

    it 'works without logger' do
      generator = described_class.new(template_path, config)
      expect(generator).to be_an_instance_of(described_class)
    end

    context 'when template file does not exist' do
      let(:non_existent_path) { '/path/that/does/not/exist.yml' }

      it 'raises an error' do
        expect { described_class.new(non_existent_path, config, logger) }
          .to raise_error(Errno::ENOENT)
      end
    end
  end

  describe '#generate' do
    let(:options) { {} }

    it_behaves_like 'YAML generator' do
      subject { described_class.new(template_path, config, logger).generate(scraped_content, options) }
    end

    it 'replaces {NAME} token with scraped title' do
      result = subject.generate(scraped_content, options)
      expect(result).to include("title: '#{scraped_content.title}'")
      expect(result).not_to include('{NAME}')
    end

    it 'replaces {URL} token with processed URL path' do
      result = subject.generate(scraped_content, options)
      expect(result).to include('url: /test-page')
      expect(result).not_to include('{URL}')
    end

    it 'replaces {SOURCE_URL} token with original URL' do
      result = subject.generate(scraped_content, options)
      expect(result).to include("uri: '#{scraped_content.url}'")
      expect(result).not_to include('{SOURCE_URL}')
    end

    it 'replaces {REPLACEME} token with scraped content' do
      result = subject.generate(scraped_content, options)
      expect(result).to include("value: '#{scraped_content.content}'")
      expect(result).not_to include('{REPLACEME}')
    end

    it 'replaces {UUID} token with valid UUID' do
      result = subject.generate(scraped_content, options)
      
      # Extract UUID from the generated YAML
      parsed = YAML.safe_load(result)
      expect_valid_uuid(parsed['uuid'])
      expect(result).not_to include('{UUID}')
    end

    it 'replaces {BLOCK_UUID} token with valid UUID' do
      result = subject.generate(scraped_content, options)
      
      # Extract block UUID from the generated YAML
      parsed = YAML.safe_load(result)
      block_uuid = parsed['custom_fields']['layout_builder__layout']['blocks'].first['uuid']
      expect_valid_uuid(block_uuid)
      expect(result).not_to include('{BLOCK_UUID}')
    end

    it 'generates different UUIDs for multiple calls' do
      result1 = subject.generate(scraped_content, options)
      result2 = subject.generate(scraped_content, options)
      
      parsed1 = YAML.safe_load(result1)
      parsed2 = YAML.safe_load(result2)
      
      expect(parsed1['uuid']).not_to eq(parsed2['uuid'])
    end

    context 'with use_domains option' do
      let(:options) { { use_domains: true } }
      let(:scraped_content_with_relative_urls) do
        TextBlockImporter::ScrapedContent.new(
          content: '<a href="/relative-link">Link</a>',
          title: 'Test Page',
          url: 'https://example.com/page',
          domain: 'example.com'
        )
      end

      it 'processes relative URLs in content' do
        allow(scraped_content_with_relative_urls).to receive(:process_relative_urls)
          .and_return('<a href="https://example.com/relative-link">Link</a>')

        subject.generate(scraped_content_with_relative_urls, options)
        expect(scraped_content_with_relative_urls).to have_received(:process_relative_urls)
      end
    end

    context 'without use_domains option' do
      it 'uses original content without processing relative URLs' do
        allow(scraped_content).to receive(:process_relative_urls)

        result = subject.generate(scraped_content, options)
        expect(scraped_content).not_to have_received(:process_relative_urls)
        expect(result).to include(scraped_content.content)
      end
    end

    context 'with complex URL paths' do
      let(:scraped_content_complex_url) do
        TextBlockImporter::ScrapedContent.new(
          content: '<p>Content</p>',
          title: 'Complex Path',
          url: 'https://example.com/category/subcategory/page-name',
          domain: 'example.com'
        )
      end

      it 'extracts basename for URL token' do
        result = subject.generate(scraped_content_complex_url, options)
        expect(result).to include('url: /page-name')
      end
    end

    context 'with URL without path' do
      let(:scraped_content_root_url) do
        TextBlockImporter::ScrapedContent.new(
          content: '<p>Content</p>',
          title: 'Root Page',
          url: 'https://example.com/',
          domain: 'example.com'
        )
      end

      it 'handles root URL gracefully' do
        result = subject.generate(scraped_content_root_url, options)
        expect(result).to include('url: /')
      end
    end

    context 'when replacement values are nil' do
      let(:scraped_content_with_nil_title) do
        TextBlockImporter::ScrapedContent.new(
          content: '<p>Content</p>',
          title: nil,
          url: 'https://example.com/page',
          domain: 'example.com'
        )
      end

      it 'warns about failed replacements and continues' do
        expect { subject.generate(scraped_content_with_nil_title, options) }
          .to output(/Could not replace for/).to_stderr

        result = subject.generate(scraped_content_with_nil_title, options)
        expect(result).to include('{NAME}') # Token remains unreplaced
      end
    end
  end

  describe '#save' do
    let(:yaml_content) { 'test: yaml content' }
    let(:temp_dir) { create_temp_directory }
    let(:output_path) { File.join(temp_dir, 'output.yml') }

    after { FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir) }

    it_behaves_like 'file operations' do
      subject { ->(path) { described_class.new(template_path, config, logger).save(yaml_content, path) } }
    end

    it 'writes YAML content to specified path' do
      subject.save(yaml_content, output_path)

      expect(File.exist?(output_path)).to be true
      expect(File.read(output_path)).to eq(yaml_content)
    end

    it 'creates directory structure when configured' do
      config_create_dirs = mock_config(
        'output' => { 'create_directories' => true }
      )
      generator = described_class.new(template_path, config_create_dirs, logger)

      nested_path = File.join(temp_dir, 'nested', 'deep', 'output.yml')
      generator.save(yaml_content, nested_path)

      expect(File.exist?(nested_path)).to be true
      expect(File.read(nested_path)).to eq(yaml_content)
    end

    it 'does not create directories when disabled' do
      config_no_create_dirs = mock_config(
        'output' => { 'create_directories' => false }
      )
      generator = described_class.new(template_path, config_no_create_dirs, logger)

      nested_path = File.join(temp_dir, 'nonexistent', 'output.yml')
      
      expect { generator.save(yaml_content, nested_path) }
        .to raise_error(Errno::ENOENT)
    end

    it 'logs debug message when saving' do
      expect(logger).to receive(:debug).with(/Writing YAML to:/)
      subject.save(yaml_content, output_path)
    end

    it 'overwrites existing files' do
      # Create initial file
      File.write(output_path, 'initial content')

      # Overwrite with new content
      subject.save(yaml_content, output_path)

      expect(File.read(output_path)).to eq(yaml_content)
    end

    context 'with permission issues' do
      before do
        skip 'Skipping permission tests on Windows' if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      end

      it 'handles permission errors gracefully' do
        # Make directory read-only
        FileUtils.chmod(0444, temp_dir)

        expect { subject.save(yaml_content, output_path) }
          .to raise_error(Errno::EACCES)
      ensure
        # Restore permissions for cleanup
        FileUtils.chmod(0755, temp_dir) if Dir.exist?(temp_dir)
      end
    end
  end

  describe 'full workflow integration' do
    let(:temp_dir) { create_temp_directory }
    let(:output_path) { File.join(temp_dir, 'integration_test.yml') }

    after { FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir) }

    it 'generates and saves complete YAML file' do
      yaml_content = subject.generate(scraped_content)
      subject.save(yaml_content, output_path)

      expect(File.exist?(output_path)).to be true
      
      # Verify the saved file is valid YAML
      saved_content = File.read(output_path)
      parsed = YAML.safe_load(saved_content)
      
      expect(parsed).to be_a(Hash)
      expect(parsed['entity_type']).to eq('node')
      expect(parsed['bundle']).to eq('page')
      expect(parsed['base_fields']['title']).to eq(scraped_content.title)
    end

    it 'maintains consistent structure across multiple generations' do
      # Generate multiple files
      3.times do |i|
        content = subject.generate(scraped_content)
        path = File.join(temp_dir, "test_#{i}.yml")
        subject.save(content, path)
      end

      # Verify all files have the same structure (but different UUIDs)
      files = Dir.glob(File.join(temp_dir, '*.yml')).sort
      parsed_files = files.map { |f| YAML.safe_load(File.read(f)) }

      expect(parsed_files.length).to eq(3)
      
      # All should have same structure
      parsed_files.each do |parsed|
        expect(parsed['entity_type']).to eq('node')
        expect(parsed['bundle']).to eq('page')
        expect(parsed['base_fields']['title']).to eq(scraped_content.title)
      end

      # But different UUIDs
      uuids = parsed_files.map { |p| p['uuid'] }
      expect(uuids.uniq.length).to eq(3)
    end
  end
end