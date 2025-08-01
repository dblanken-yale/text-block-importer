# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe TextBlockImporter::Config do
  let(:temp_dir) { create_temp_directory }
  
  after { FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir) }
  
  def config_with_data(data)
    config = described_class.new
    config.instance_variable_set(:@data, data)
    config
  end

  describe '#initialize' do
    context 'without custom config path' do
      it 'creates a new instance with default configuration' do
        config = described_class.new
        expect(config).to be_an_instance_of(described_class)
        expect(config.data).to be_a(Hash)
      end

      it 'loads default configuration from config/default.yml' do
        config = described_class.new
        expect(config.timeout).to eq(30)
        expect(config.retries).to eq(3)
        expect(config.user_agent).to eq('TextBlockImporter/2.0')
      end
    end

    context 'with custom config path' do
      let(:custom_config_path) { File.join(temp_dir, 'custom_config.yml') }
      let(:custom_config_content) do
        <<~YAML
          http:
            timeout: 60
            retries: 5
            user_agent: "CustomAgent/1.0"
          processing:
            strip_newlines: false
        YAML
      end

      before do
        File.write(custom_config_path, custom_config_content)
      end

      it 'loads configuration from specified path' do
        config = described_class.new(config_path: custom_config_path)
        
        expect(config.timeout).to eq(60)
        expect(config.retries).to eq(5)
        expect(config.user_agent).to eq('CustomAgent/1.0')
        expect(config.strip_newlines?).to be false
      end

      it 'merges custom config with defaults' do
        config = described_class.new(config_path: custom_config_path)
        
        # Custom values
        expect(config.timeout).to eq(60)
        expect(config.strip_newlines?).to be false
        
        # Default values that weren't overridden
        expect(config.encode_quotes?).to be true
        expect(config.warn_empty_content?).to be true
      end
    end

    context 'with non-existent config file' do
      let(:non_existent_path) { File.join(temp_dir, 'does_not_exist.yml') }

      it 'uses default configuration when custom file does not exist' do
        config = described_class.new(config_path: non_existent_path)
        
        # Should fall back to defaults
        expect(config.timeout).to eq(30)
        expect(config.retries).to eq(3)
      end
    end

    context 'with invalid YAML file' do
      let(:invalid_yaml_path) { File.join(temp_dir, 'invalid.yml') }

      before do
        File.write(invalid_yaml_path, 'invalid: yaml: content: [unclosed')
      end

      it 'handles invalid YAML gracefully' do
        expect { described_class.new(config_path: invalid_yaml_path) }
          .to raise_error(Psych::SyntaxError)
      end
    end

    context 'with multiple config files' do
      let(:global_config_path) { File.join(temp_dir, '.text_block_importer.yml') }
      let(:local_config_path) { File.join(temp_dir, 'text_block_importer.yml') }

      let(:global_config) do
        <<~YAML
          http:
            timeout: 45
            retries: 2
          processing:
            strip_newlines: false
            encode_quotes: false
        YAML
      end

      let(:local_config) do
        <<~YAML
          http:
            timeout: 60
          processing:
            encode_quotes: true
          output:
            base_directory: "custom_output"
        YAML
      end

      before do
        File.write(global_config_path, global_config)
        File.write(local_config_path, local_config)

        # Mock the DEFAULT_CONFIG_PATHS to include our temp files
        stub_const('TextBlockImporter::Config::DEFAULT_CONFIG_PATHS', [
          fixture_path('../config/default.yml'),
          global_config_path,
          local_config_path
        ])
      end

      it 'merges multiple configuration files with proper precedence' do
        config = described_class.new

        # Local config should override global config
        expect(config.timeout).to eq(60)
        expect(config.encode_quotes?).to be true
        
        # Global config values not overridden by local
        expect(config.retries).to eq(2)
        expect(config.strip_newlines?).to be false
        
        # Local config only values
        expect(config.base_directory).to eq('custom_output')
      end
    end
  end

  describe 'HTTP settings' do
    let(:http_config) do
      {
        'http' => {
          'timeout' => 120,
          'retries' => 5,
          'user_agent' => 'TestAgent/2.0',
          'follow_redirects' => false
        }
      }
    end

    subject { config_with_data(http_config) }

    describe '#user_agent' do
      it 'returns configured user agent' do
        expect(subject.user_agent).to eq('TestAgent/2.0')
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.user_agent).to eq('TextBlockImporter/2.0')
      end
    end

    describe '#timeout' do
      it 'returns configured timeout' do
        expect(subject.timeout).to eq(120)
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.timeout).to eq(30)
      end
    end

    describe '#retries' do
      it 'returns configured retries' do
        expect(subject.retries).to eq(5)
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.retries).to eq(3)
      end
    end

    describe '#follow_redirects?' do
      it 'returns configured redirect setting' do
        expect(subject.follow_redirects?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.follow_redirects?).to be true
      end
    end
  end

  describe 'logging settings' do
    let(:logging_config) do
      {
        'logging' => {
          'level' => 'debug',
          'output' => 'stderr'
        }
      }
    end

    subject do
      config = described_class.new
      allow(config).to receive(:data).and_return(logging_config)
      config
    end

    describe '#log_level' do
      it 'returns configured log level as symbol' do
        expect(subject.log_level).to eq(:debug)
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.log_level).to eq(:info)
      end
    end

    describe '#log_output' do
      it 'returns stderr for stderr configuration' do
        expect(subject.log_output).to eq($stderr)
      end

      it 'returns stdout for stdout configuration' do
        allow(subject).to receive(:data).and_return({'logging' => {'output' => 'stdout'}})
        expect(subject.log_output).to eq($stdout)
      end

      it 'returns file handle for file path configuration' do
        log_file_path = File.join(temp_dir, 'test.log')
        allow(subject).to receive(:data).and_return({'logging' => {'output' => log_file_path}})
        
        output = subject.log_output
        expect(output).to be_a(File)
        output.close
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.log_output).to eq($stdout)
      end
    end
  end

  describe 'processing settings' do
    let(:processing_config) do
      {
        'processing' => {
          'strip_newlines' => false,
          'encode_quotes' => false,
          'warn_empty_content' => false
        }
      }
    end

    subject do
      config = described_class.new
      allow(config).to receive(:data).and_return(processing_config)
      config
    end

    describe '#strip_newlines?' do
      it 'returns configured setting' do
        expect(subject.strip_newlines?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.strip_newlines?).to be true
      end
    end

    describe '#encode_quotes?' do
      it 'returns configured setting' do
        expect(subject.encode_quotes?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.encode_quotes?).to be true
      end
    end

    describe '#warn_empty_content?' do
      it 'returns configured setting' do
        expect(subject.warn_empty_content?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.warn_empty_content?).to be true
      end
    end
  end

  describe 'template settings' do
    let(:template_config) do
      {
        'templates' => {
          'tokens' => {
            'name_selector' => 'h2.title',
            'encode_title' => false
          }
        }
      }
    end

    subject do
      config = described_class.new
      config.instance_variable_set(:@data, template_config)
      config
    end

    describe '#name_selector' do
      it 'returns configured selector' do
        expect(subject.name_selector).to eq('h2.title')
      end

      it 'returns default when not configured' do
        config = config_with_data({})
        expect(config.name_selector).to eq('h1')
      end
    end

    describe '#encode_title?' do
      it 'returns configured setting' do
        expect(subject.encode_title?).to be false
      end

      it 'returns default when not configured' do
        config = config_with_data({})
        expect(config.encode_title?).to be true
      end
    end
  end

  describe 'batch settings' do
    let(:batch_config) do
      {
        'batch' => {
          'show_progress' => false,
          'continue_on_error' => false
        }
      }
    end

    subject { config_with_data(batch_config) }

    describe '#show_progress?' do
      it 'returns configured setting' do
        expect(subject.show_progress?).to be false
      end

      it 'returns default when not configured' do
        config = config_with_data({})
        expect(config.show_progress?).to be true
      end
    end

    describe '#continue_on_error?' do
      it 'returns configured setting' do
        expect(subject.continue_on_error?).to be false
      end

      it 'returns default when not configured' do
        config = config_with_data({})
        expect(config.continue_on_error?).to be true
      end
    end
  end

  describe 'output settings' do
    let(:output_config) do
      {
        'output' => {
          'filename_pattern' => 'custom-{index}.yml',
          'create_directories' => false,
          'base_directory' => 'custom_output',
          'use_domain_directories' => false,
          'sanitize_domain_names' => false
        }
      }
    end

    subject do
      config = described_class.new
      allow(config).to receive(:data).and_return(output_config)
      config
    end

    describe '#filename_pattern' do
      it 'returns configured pattern' do
        expect(subject.filename_pattern).to eq('custom-{index}.yml')
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.filename_pattern).to eq('node-{index}.output.yml')
      end
    end

    describe '#create_directories?' do
      it 'returns configured setting' do
        expect(subject.create_directories?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.create_directories?).to be true
      end
    end

    describe '#base_directory' do
      it 'returns configured directory' do
        expect(subject.base_directory).to eq('custom_output')
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.base_directory).to eq('output')
      end
    end

    describe '#use_domain_directories?' do
      it 'returns configured setting' do
        expect(subject.use_domain_directories?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.use_domain_directories?).to be true
      end
    end

    describe '#sanitize_domain_names?' do
      it 'returns configured setting' do
        expect(subject.sanitize_domain_names?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.sanitize_domain_names?).to be true
      end
    end
  end

  describe 'sitemap settings' do
    let(:sitemap_config) do
      {
        'sitemap' => {
          'recursive' => false,
          'max_depth' => 5,
          'same_domain_only' => false
        }
      }
    end

    subject do
      config = described_class.new
      allow(config).to receive(:data).and_return(sitemap_config)
      config
    end

    describe '#sitemap_recursive?' do
      it 'returns configured setting' do
        expect(subject.sitemap_recursive?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.sitemap_recursive?).to be true
      end
    end

    describe '#sitemap_max_depth' do
      it 'returns configured depth' do
        expect(subject.sitemap_max_depth).to eq(5)
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.sitemap_max_depth).to eq(3)
      end
    end

    describe '#sitemap_same_domain_only?' do
      it 'returns configured setting' do
        expect(subject.sitemap_same_domain_only?).to be false
      end

      it 'returns default when not configured' do
        allow(subject).to receive(:data).and_return({})
        expect(subject.sitemap_same_domain_only?).to be true
      end
    end
  end

  describe 'section accessors' do
    let(:full_config) do
      {
        'http' => { 'timeout' => 60 },
        'logging' => { 'level' => 'debug' },
        'processing' => { 'strip_newlines' => false },
        'templates' => { 'tokens' => { 'name_selector' => 'h2' } },
        'batch' => { 'show_progress' => false },
        'output' => { 'base_directory' => 'test' },
        'sitemap' => { 'recursive' => false }
      }
    end

    subject { config_with_data(full_config) }

    it 'provides access to http section' do
      expect(subject.http).to eq({ 'timeout' => 60 })
    end

    it 'provides access to logging section' do
      expect(subject.logging).to eq({ 'level' => 'debug' })
    end

    it 'provides access to processing section' do
      expect(subject.processing).to eq({ 'strip_newlines' => false })
    end

    it 'provides access to templates section' do
      expect(subject.templates).to eq({ 'tokens' => { 'name_selector' => 'h2' } })
    end

    it 'provides access to batch section' do
      expect(subject.batch).to eq({ 'show_progress' => false })
    end

    it 'provides access to output section' do
      expect(subject.output).to eq({ 'base_directory' => 'test' })
    end

    it 'provides access to sitemap section' do
      expect(subject.sitemap).to eq({ 'recursive' => false })
    end

    it 'returns empty hash for missing sections' do
      allow(subject).to receive(:data).and_return({})
      expect(subject.http).to eq({})
      expect(subject.logging).to eq({})
    end
  end

  describe 'deep merge functionality' do
    let(:base_config_path) { File.join(temp_dir, 'base.yml') }
    let(:override_config_path) { File.join(temp_dir, 'override.yml') }

    let(:base_config) do
      <<~YAML
        http:
          timeout: 30
          retries: 3
          user_agent: "Base/1.0"
        processing:
          strip_newlines: true
          encode_quotes: true
        nested:
          deep:
            value1: "base"
            value2: "base"
      YAML
    end

    let(:override_config) do
      <<~YAML
        http:
          timeout: 60
          follow_redirects: false
        processing:
          encode_quotes: false
        nested:
          deep:
            value1: "override"
            value3: "override"
      YAML
    end

    before do
      File.write(base_config_path, base_config)
      File.write(override_config_path, override_config)

      stub_const('TextBlockImporter::Config::DEFAULT_CONFIG_PATHS', [
        base_config_path,
        override_config_path
      ])
    end

    it 'performs deep merge of nested configuration hashes' do
      config = described_class.new

      # Merged HTTP values
      expect(config.timeout).to eq(60) # overridden
      expect(config.retries).to eq(3) # from base
      expect(config.user_agent).to eq('Base/1.0') # from base
      expect(config.follow_redirects?).to be false # from override

      # Merged processing values
      expect(config.strip_newlines?).to be true # from base
      expect(config.encode_quotes?).to be false # overridden

      # Deep nested values
      expect(config.data.dig('nested', 'deep', 'value1')).to eq('override')
      expect(config.data.dig('nested', 'deep', 'value2')).to eq('base')
      expect(config.data.dig('nested', 'deep', 'value3')).to eq('override')
    end
  end
end