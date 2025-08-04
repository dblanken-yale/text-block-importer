# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TextBlockImporter::PathHelper do
  let(:temp_dir) { create_temp_directory }
  let(:base_config) do
    config = TextBlockImporter::Config.new
    config.instance_variable_set('@data', {
      'output' => {
        'base_directory' => temp_dir,
        'use_domain_directories' => false,
        'create_directories' => true,
        'sanitize_domain_names' => true,
        'filename_pattern' => 'node-{index}.output.yml'
      }
    })
    config
  end
  let(:logger) { double('Logger', debug: nil, warn: nil) }
  let(:path_helper) { described_class.new(base_config, logger) }

  describe '#initialize' do
    it 'creates a new instance with config and logger' do
      expect(described_class.new(base_config, logger)).to be_a described_class
    end

    it 'works without logger' do
      expect(described_class.new(base_config)).to be_a described_class
    end
  end

  describe '#build_output_path' do
    context 'without domain directories' do
      it 'returns base directory when no filename provided' do
        result = path_helper.build_output_path('https://example.com')
        expect(result).to eq(temp_dir)
      end

      it 'returns full path when filename provided' do
        result = path_helper.build_output_path('https://example.com', 'test.yml')
        expect(result).to eq(File.join(temp_dir, 'test.yml'))
      end

      it 'creates base directory if it does not exist' do
        new_base = File.join(temp_dir, 'new_base')
        base_config.instance_variable_get('@data')['output']['base_directory'] = new_base
        
        result = path_helper.build_output_path('https://example.com')
        
        expect(Dir.exist?(new_base)).to be true
        expect(result).to eq(new_base)
      end
    end

    context 'with domain directories enabled' do
      before do
        base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true
      end

      it 'creates domain-based directory structure' do
        result = path_helper.build_output_path('https://example.com', 'test.yml')
        expected_dir = File.join(temp_dir, 'example.com')
        expected_path = File.join(expected_dir, 'test.yml')
        
        expect(result).to eq(expected_path)
        expect(Dir.exist?(expected_dir)).to be true
      end

      it 'handles subdomains correctly' do
        result = path_helper.build_output_path('https://api.example.com', 'test.yml')
        expected_dir = File.join(temp_dir, 'api.example.com')
        expected_path = File.join(expected_dir, 'test.yml')
        
        expect(result).to eq(expected_path)
        expect(Dir.exist?(expected_dir)).to be true
      end

      it 'sanitizes domain names when enabled' do
        result = path_helper.build_output_path('https://my-site.example.com', 'test.yml')
        expected_dir = File.join(temp_dir, 'my-site.example.com')
        expected_path = File.join(expected_dir, 'test.yml')
        
        expect(result).to eq(expected_path)
        expect(Dir.exist?(expected_dir)).to be true
      end

      it 'handles invalid URLs gracefully' do
        result = path_helper.build_output_path('invalid-url', 'test.yml')
        expected_dir = File.join(temp_dir, 'unknown-domain')
        expected_path = File.join(expected_dir, 'test.yml')
        
        expect(result).to eq(expected_path)
        expect(Dir.exist?(expected_dir)).to be true
      end

      it 'returns directory path when no filename provided' do
        result = path_helper.build_output_path('https://example.com')
        expected_dir = File.join(temp_dir, 'example.com')
        
        expect(result).to eq(expected_dir)
        expect(Dir.exist?(expected_dir)).to be true
      end
    end

    context 'when directory creation is disabled' do
      before do
        base_config.instance_variable_get('@data')['output']['create_directories'] = false
        base_config.instance_variable_get('@data')['output']['base_directory'] = File.join(temp_dir, 'nonexistent')
      end

      it 'raises error when directory does not exist' do
        expect { path_helper.build_output_path('https://example.com') }
          .to raise_error(TextBlockImporter::ValidationError, /Output directory does not exist/)
      end
    end

    context 'with logger' do
      it 'logs debug message when creating directories' do
        new_dir = File.join(temp_dir, 'new_directory')
        base_config.instance_variable_get('@data')['output']['base_directory'] = new_dir
        
        expect(logger).to receive(:debug).with("Creating directory: #{new_dir}")
        
        path_helper.build_output_path('https://example.com')
      end
    end

    context 'without logger' do
      let(:path_helper_no_logger) { described_class.new(base_config) }

      it 'works without logger when creating directories' do
        new_dir = File.join(temp_dir, 'new_directory')
        base_config.instance_variable_get('@data')['output']['base_directory'] = new_dir
        
        expect { path_helper_no_logger.build_output_path('https://example.com') }.not_to raise_error
        expect(Dir.exist?(new_dir)).to be true
      end

      it 'works without logger when handling invalid URLs' do
        base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true
        
        expect { path_helper_no_logger.build_output_path('invalid-url', 'test.yml') }.not_to raise_error
      end
    end
  end

  describe '#build_sitemap_output_path' do
    it 'uses default filename when none provided' do
      result = path_helper.build_sitemap_output_path('https://example.com')
      expect(result).to eq(File.join(temp_dir, 'sitemap.links'))
    end

    it 'uses custom filename when provided' do
      result = path_helper.build_sitemap_output_path('https://example.com', 'custom.links')
      expect(result).to eq(File.join(temp_dir, 'custom.links'))
    end

    it 'respects domain directories configuration' do
      base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true
      
      result = path_helper.build_sitemap_output_path('https://example.com', 'sitemap.txt')
      expected_path = File.join(temp_dir, 'example.com', 'sitemap.txt')
      
      expect(result).to eq(expected_path)
    end
  end

  describe '#build_batch_output_path' do
    it 'generates filename using pattern with index replacement' do
      result = path_helper.build_batch_output_path('https://example.com', 5)
      expected_path = File.join(temp_dir, 'node-5.output.yml')
      
      expect(result).to eq(expected_path)
    end

    it 'works with different filename patterns' do
      base_config.instance_variable_get('@data')['output']['filename_pattern'] = 'page-{index}.yaml'
      
      result = path_helper.build_batch_output_path('https://example.com', 10)
      expected_path = File.join(temp_dir, 'page-10.yaml')
      
      expect(result).to eq(expected_path)
    end

    it 'respects domain directories configuration' do
      base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true
      
      result = path_helper.build_batch_output_path('https://api.example.com', 3)
      expected_path = File.join(temp_dir, 'api.example.com', 'node-3.output.yml')
      
      expect(result).to eq(expected_path)
    end

    it 'handles zero-padded indices' do
      base_config.instance_variable_get('@data')['output']['filename_pattern'] = 'item-{index}.yml'
      
      result = path_helper.build_batch_output_path('https://example.com', 7)
      expected_path = File.join(temp_dir, 'item-7.yml')
      
      expect(result).to eq(expected_path)
    end
  end

  describe 'private methods' do
    describe '#extract_domain' do
      let(:path_helper_test) { described_class.new(base_config, logger) }

      it 'extracts domain from standard HTTP URL' do
        result = path_helper_test.send(:extract_domain, 'http://example.com/path')
        expect(result).to eq('example.com')
      end

      it 'extracts domain from HTTPS URL' do
        result = path_helper_test.send(:extract_domain, 'https://secure.example.com/path?query=value')
        expect(result).to eq('secure.example.com')
      end

      it 'extracts domain from URL with port' do
        result = path_helper_test.send(:extract_domain, 'https://example.com:8080/path')
        expect(result).to eq('example.com')
      end

      it 'handles invalid URLs gracefully' do
        result = path_helper_test.send(:extract_domain, 'not-a-url')
        expect(result).to eq('unknown-domain')
      end

      it 'handles malformed URLs' do
        result = path_helper_test.send(:extract_domain, 'https://')
        expect(result).to eq('unknown-domain')
      end

      it 'logs warning for truly invalid URIs' do
        expect(logger).to receive(:warn).with(/Invalid URL/)
        
        result = path_helper_test.send(:extract_domain, 'http://[invalid')
        expect(result).to eq('unknown-domain')
      end
    end

    describe '#sanitize_domain' do
      let(:path_helper_test) { described_class.new(base_config, logger) }

      context 'when sanitization is enabled' do
        it 'preserves valid domain characters' do
          result = path_helper_test.send(:sanitize_domain, 'example.com')
          expect(result).to eq('example.com')
        end

        it 'preserves hyphens in domain names' do
          result = path_helper_test.send(:sanitize_domain, 'my-site.example.com')
          expect(result).to eq('my-site.example.com')
        end

        it 'replaces invalid characters with underscores' do
          result = path_helper_test.send(:sanitize_domain, 'site@example.com')
          expect(result).to eq('site_example.com')
        end

        it 'handles multiple invalid characters' do
          result = path_helper_test.send(:sanitize_domain, 'test<>site.example.com')
          expect(result).to eq('test__site.example.com')
        end

        it 'removes leading dots and underscores' do
          result = path_helper_test.send(:sanitize_domain, '.example.com')
          expect(result).to eq('example.com')
        end

        it 'removes trailing dots and underscores' do
          result = path_helper_test.send(:sanitize_domain, 'example.com.')
          expect(result).to eq('example.com')
        end

        it 'removes leading and trailing dots/underscores' do
          result = path_helper_test.send(:sanitize_domain, '_.example.com._')
          expect(result).to eq('example.com')
        end

        it 'handles edge case with only dots and underscores' do
          result = path_helper_test.send(:sanitize_domain, '.._.')
          expect(result).to eq('sanitized-domain')
        end

        it 'handles nil domain' do
          result = path_helper_test.send(:sanitize_domain, nil)
          expect(result).to eq('empty-domain')
        end

        it 'handles empty domain' do
          result = path_helper_test.send(:sanitize_domain, '')
          expect(result).to eq('empty-domain')
        end
      end

      context 'when sanitization is disabled' do
        before do
          base_config.instance_variable_get('@data')['output']['sanitize_domain_names'] = false
        end

        it 'returns domain unchanged' do
          result = path_helper_test.send(:sanitize_domain, 'site@example.com')
          expect(result).to eq('site@example.com')
        end

        it 'preserves special characters' do
          result = path_helper_test.send(:sanitize_domain, 'test<>site.example.com')
          expect(result).to eq('test<>site.example.com')
        end
      end
    end

    describe '#ensure_directory_exists' do
      let(:path_helper_test) { described_class.new(base_config, logger) }

      context 'when directory exists' do
        it 'does nothing' do
          expect(FileUtils).not_to receive(:mkdir_p)
          path_helper_test.send(:ensure_directory_exists, temp_dir)
        end
      end

      context 'when directory does not exist and creation is enabled' do
        let(:new_dir) { File.join(temp_dir, 'new_directory') }

        it 'creates the directory' do
          expect(logger).to receive(:debug).with("Creating directory: #{new_dir}")
          
          path_helper_test.send(:ensure_directory_exists, new_dir)
          expect(Dir.exist?(new_dir)).to be true
        end

        it 'creates nested directories' do
          nested_dir = File.join(temp_dir, 'level1', 'level2', 'level3')
          expect(logger).to receive(:debug).with("Creating directory: #{nested_dir}")
          
          path_helper_test.send(:ensure_directory_exists, nested_dir)
          expect(Dir.exist?(nested_dir)).to be true
        end
      end

      context 'when directory does not exist and creation is disabled' do
        before do
          base_config.instance_variable_get('@data')['output']['create_directories'] = false
        end

        it 'raises ValidationError' do
          new_dir = File.join(temp_dir, 'nonexistent')
          
          expect { path_helper_test.send(:ensure_directory_exists, new_dir) }
            .to raise_error(TextBlockImporter::ValidationError, "Output directory does not exist: #{new_dir}")
        end
      end
    end
  end

  describe 'integration scenarios' do
    context 'full workflow with domain directories' do
      before do
        base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true
      end

      it 'handles complete batch processing path generation' do
        urls = [
          'https://example.com/page1',
          'https://api.example.com/page2',
          'https://subdomain.example.org/page3'
        ]

        paths = urls.map.with_index(1) do |url, index|
          path_helper.build_batch_output_path(url, index)
        end

        expect(paths[0]).to end_with('example.com/node-1.output.yml')
        expect(paths[1]).to end_with('api.example.com/node-2.output.yml')
        expect(paths[2]).to end_with('subdomain.example.org/node-3.output.yml')

        # Verify all directories were created
        paths.each { |path| expect(Dir.exist?(File.dirname(path))).to be true }
      end
    end

    context 'error handling in complex scenarios' do
      it 'handles mixed valid and invalid URLs in batch' do
        base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true

        urls = [
          'https://example.com/page1',
          'invalid-url-1',
          'https://valid.com/page2',
          'not-a-url-either'
        ]

        paths = urls.map.with_index(1) do |url, index|
          path_helper.build_batch_output_path(url, index)
        end

        expect(paths[0]).to end_with('example.com/node-1.output.yml')
        expect(paths[1]).to end_with('unknown-domain/node-2.output.yml')
        expect(paths[2]).to end_with('valid.com/node-3.output.yml')
        expect(paths[3]).to end_with('unknown-domain/node-4.output.yml')
      end
    end

    context 'performance considerations' do
      it 'does not recreate existing directories repeatedly' do
        base_config.instance_variable_get('@data')['output']['use_domain_directories'] = true
        
        # First call should create directory and log
        expect(logger).to receive(:debug).with(/Creating directory/).once
        
        # Generate multiple paths for same domain
        5.times do |i|
          path_helper.build_batch_output_path('https://example.com/page', i + 1)
        end
      end
    end
  end
end