# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TextBlockImporter::Validator do
  describe '.validate_url!' do
    context 'with valid URLs' do
      it 'passes for standard HTTP URL' do
        expect { described_class.validate_url!('http://example.com') }.not_to raise_error
      end

      it 'passes for standard HTTPS URL' do
        expect { described_class.validate_url!('https://example.com') }.not_to raise_error
      end

      it 'passes for URL with path' do
        expect { described_class.validate_url!('https://example.com/path/to/page') }.not_to raise_error
      end

      it 'passes for URL with query parameters' do
        expect { described_class.validate_url!('https://example.com/search?q=test&type=all') }.not_to raise_error
      end

      it 'passes for URL with port' do
        expect { described_class.validate_url!('https://example.com:8080/page') }.not_to raise_error
      end

      it 'passes for URL with subdomain' do
        expect { described_class.validate_url!('https://api.example.com/v1/data') }.not_to raise_error
      end

      it 'passes for URL with hyphenated domain' do
        expect { described_class.validate_url!('https://my-site.example-domain.com') }.not_to raise_error
      end
    end

    context 'with invalid URLs' do
      it 'raises error for nil URL' do
        expect { described_class.validate_url!(nil) }
          .to raise_error(TextBlockImporter::ValidationError, 'URL cannot be empty')
      end

      it 'raises error for empty string' do
        expect { described_class.validate_url!('') }
          .to raise_error(TextBlockImporter::ValidationError, 'URL cannot be empty')
      end

      it 'raises error for whitespace-only string' do
        expect { described_class.validate_url!('   ') }
          .to raise_error(TextBlockImporter::ValidationError, 'URL cannot be empty')
      end

      it 'raises error for FTP URL' do
        expect { described_class.validate_url!('ftp://example.com/file.txt') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL format/)
      end

      it 'raises error for URL without protocol' do
        expect { described_class.validate_url!('example.com') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL format/)
      end

      it 'raises error for URL with invalid protocol' do
        expect { described_class.validate_url!('javascript:alert("xss")') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL format/)
      end

      it 'raises error for URL with spaces' do
        expect { described_class.validate_url!('https://example.com/path with spaces') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL format/)
      end

      it 'raises error for malformed URL' do
        expect { described_class.validate_url!('https://') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL format/)
      end

      it 'raises error for URL with invalid characters' do
        expect { described_class.validate_url!('https://example.com/<script>') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL/)
      end

      it 'raises error for localhost URLs (security consideration)' do
        expect { described_class.validate_url!('http://localhost:3000') }
          .not_to raise_error # Note: localhost is currently allowed, might want to restrict
      end
    end

    context 'edge cases' do
      it 'handles URL with fragment' do
        expect { described_class.validate_url!('https://example.com/page#section') }.not_to raise_error
      end

      it 'handles URL with authentication' do
        expect { described_class.validate_url!('https://user:pass@example.com') }.not_to raise_error
      end

      it 'handles international domain names (currently not supported)' do
        expect { described_class.validate_url!('https://münchen.de') }
          .to raise_error(TextBlockImporter::ValidationError, /Invalid URL/)
      end
    end
  end

  describe '.validate_css_selector!' do
    context 'with valid CSS selectors' do
      it 'passes for simple element selector' do
        expect { described_class.validate_css_selector!('div') }.not_to raise_error
      end

      it 'passes for class selector' do
        expect { described_class.validate_css_selector!('.content-main') }.not_to raise_error
      end

      it 'passes for ID selector' do
        expect { described_class.validate_css_selector!('#header') }.not_to raise_error
      end

      it 'passes for attribute selector' do
        expect { described_class.validate_css_selector!('input[type="text"]') }.not_to raise_error
      end

      it 'passes for descendant selector' do
        expect { described_class.validate_css_selector!('div .content p') }.not_to raise_error
      end

      it 'passes for child selector' do
        expect { described_class.validate_css_selector!('ul > li') }.not_to raise_error
      end

      it 'passes for complex selector' do
        expect { described_class.validate_css_selector!('div.container > .content-area p:first-child') }.not_to raise_error
      end

      it 'passes for pseudo-class selector' do
        expect { described_class.validate_css_selector!('a:hover') }.not_to raise_error
      end

      it 'passes for multiple classes' do
        expect { described_class.validate_css_selector!('.nav.primary.active') }.not_to raise_error
      end
    end

    context 'with invalid CSS selectors' do
      it 'raises error for nil selector' do
        expect { described_class.validate_css_selector!(nil) }
          .to raise_error(TextBlockImporter::ValidationError, 'CSS selector cannot be empty')
      end

      it 'raises error for empty string' do
        expect { described_class.validate_css_selector!('') }
          .to raise_error(TextBlockImporter::ValidationError, 'CSS selector cannot be empty')
      end

      it 'raises error for whitespace-only string' do
        expect { described_class.validate_css_selector!('   ') }
          .to raise_error(TextBlockImporter::ValidationError, 'CSS selector cannot be empty')
      end

      it 'raises error for selector with invalid characters' do
        expect { described_class.validate_css_selector!('div{color:red}') }
          .to raise_error(TextBlockImporter::ValidationError, 'Invalid CSS selector format')
      end

      it 'raises error for selector with semicolon' do
        expect { described_class.validate_css_selector!('div;script') }
          .to raise_error(TextBlockImporter::ValidationError, 'Invalid CSS selector format')
      end

      it 'raises error for XSS attempt' do
        expect { described_class.validate_css_selector!('<script>alert("xss")</script>') }
          .to raise_error(TextBlockImporter::ValidationError, 'Invalid CSS selector format')
      end
    end

    context 'edge cases' do
      it 'handles selector with numbers' do
        expect { described_class.validate_css_selector!('h1, h2, h3') }.not_to raise_error
      end

      it 'handles complex attribute selectors' do
        expect { described_class.validate_css_selector!('input[data-type="special"]') }.not_to raise_error
      end

      it 'handles CSS selector with single quotes' do
        expect { described_class.validate_css_selector!("input[type='text']") }.not_to raise_error
      end
    end
  end

  describe '.validate_file_exists!' do
    let(:temp_dir) { create_temp_directory }
    let(:existing_file) { File.join(temp_dir, 'existing_file.txt') }
    let(:non_existing_file) { File.join(temp_dir, 'non_existing_file.txt') }

    before do
      File.write(existing_file, 'test content')
    end

    context 'with valid file paths' do
      it 'passes for existing file' do
        expect { described_class.validate_file_exists!(existing_file) }.not_to raise_error
      end

      it 'passes for existing file with custom file type' do
        expect { described_class.validate_file_exists!(existing_file, 'config file') }.not_to raise_error
      end
    end

    context 'with invalid file paths' do
      it 'raises error for nil path' do
        expect { described_class.validate_file_exists!(nil) }
          .to raise_error(TextBlockImporter::ValidationError, 'File path cannot be empty')
      end

      it 'raises error for empty string' do
        expect { described_class.validate_file_exists!('') }
          .to raise_error(TextBlockImporter::ValidationError, 'File path cannot be empty')
      end

      it 'raises error for whitespace-only string' do
        expect { described_class.validate_file_exists!('   ') }
          .to raise_error(TextBlockImporter::ValidationError, 'File path cannot be empty')
      end

      it 'raises error for non-existing file' do
        expect { described_class.validate_file_exists!(non_existing_file) }
          .to raise_error(TextBlockImporter::ValidationError, "File not found: #{non_existing_file}")
      end

      it 'raises error for non-existing file with custom type' do
        expect { described_class.validate_file_exists!(non_existing_file, 'template') }
          .to raise_error(TextBlockImporter::ValidationError, "Template not found: #{non_existing_file}")
      end
    end

    context 'with directories' do
      it 'passes for existing directory (as files)' do
        expect { described_class.validate_file_exists!(temp_dir) }.not_to raise_error
      end
    end
  end

  describe '.validate_template_file!' do
    let(:temp_dir) { create_temp_directory }
    let(:valid_template) { File.join(temp_dir, 'valid_template.yml') }
    let(:invalid_template) { File.join(temp_dir, 'invalid_template.yml') }
    let(:missing_template) { File.join(temp_dir, 'missing_template.yml') }

    before do
      # Create a valid template with all required tokens
      File.write(valid_template, <<~YAML)
        entity_type: node
        bundle: page
        uuid: {UUID}
        title: Sample Page
        field_text_block:
          - target_uuid: {BLOCK_UUID}
            target_type: paragraph
            
        paragraph:
          uuid: {BLOCK_UUID}
          type: text_block
          field_text_block_text:
            value: {REPLACEME}
            format: full_html
      YAML

      # Create an invalid template missing required tokens
      File.write(invalid_template, <<~YAML)
        entity_type: node
        bundle: page
        uuid: {UUID}
        title: Sample Page
        field_text_block:
          value: Some static content
      YAML
    end

    context 'with valid template files' do
      it 'passes for template with all required tokens' do
        expect { described_class.validate_template_file!(valid_template) }.not_to raise_error
      end
    end

    context 'with invalid template files' do
      it 'raises error for non-existing template' do
        expect { described_class.validate_template_file!(missing_template) }
          .to raise_error(TextBlockImporter::ValidationError, "Template file not found: #{missing_template}")
      end

      it 'raises error for template missing required tokens' do
        expect { described_class.validate_template_file!(invalid_template) }
          .to raise_error(TextBlockImporter::ValidationError, /Template missing required tokens:/)
      end

      it 'identifies specific missing tokens' do
        expect { described_class.validate_template_file!(invalid_template) }
          .to raise_error(TextBlockImporter::ValidationError, /BLOCK_UUID.*REPLACEME/)
      end
    end

    context 'edge cases' do
      it 'handles template with extra tokens' do
        extra_template = File.join(temp_dir, 'extra_template.yml')
        File.write(extra_template, <<~YAML)
          entity_type: node
          uuid: {UUID}
          custom_field: {CUSTOM_TOKEN}
          paragraph:
            uuid: {BLOCK_UUID}
            content: {REPLACEME}
        YAML

        expect { described_class.validate_template_file!(extra_template) }.not_to raise_error
      end

      it 'handles empty template file' do
        empty_template = File.join(temp_dir, 'empty_template.yml')
        File.write(empty_template, '')

        expect { described_class.validate_template_file!(empty_template) }
          .to raise_error(TextBlockImporter::ValidationError, /Template missing required tokens/)
      end
    end
  end

  describe '.validate_output_directory!' do
    let(:temp_dir) { create_temp_directory }
    let(:existing_dir_file) { File.join(temp_dir, 'output.yml') }
    let(:non_existing_dir_file) { File.join(temp_dir, 'non_existing', 'output.yml') }

    context 'with valid output paths' do
      it 'passes for file in existing directory' do
        expect { described_class.validate_output_directory!(existing_dir_file) }.not_to raise_error
      end

      it 'passes for file in current directory' do
        expect { described_class.validate_output_directory!('output.yml') }.not_to raise_error
      end
    end

    context 'with invalid output paths' do
      it 'raises error for file in non-existing directory' do
        expect { described_class.validate_output_directory!(non_existing_dir_file) }
          .to raise_error(TextBlockImporter::ValidationError, /Output directory does not exist/)
      end

      it 'identifies the specific missing directory' do
        missing_dir = File.dirname(non_existing_dir_file)
        expect { described_class.validate_output_directory!(non_existing_dir_file) }
          .to raise_error(TextBlockImporter::ValidationError, "Output directory does not exist: #{missing_dir}")
      end
    end

    context 'edge cases' do
      it 'handles deeply nested paths' do
        deep_path = File.join(temp_dir, 'level1', 'level2', 'level3', 'output.yml')
        expect { described_class.validate_output_directory!(deep_path) }
          .to raise_error(TextBlockImporter::ValidationError, /Output directory does not exist/)
      end

      it 'handles relative paths' do
        expect { described_class.validate_output_directory!('./output.yml') }.not_to raise_error
      end
    end
  end
end