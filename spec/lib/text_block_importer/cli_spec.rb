# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe TextBlockImporter::CLI do
  let(:config) { instance_double('TextBlockImporter::Config') }
  let(:logger) { instance_double('TextBlockImporter::CustomLogger') }
  let(:logger_with_context) { instance_double('TextBlockImporter::CustomLogger') }
  
  before do
    allow(TextBlockImporter::Config).to receive(:new).and_return(config)
    allow(TextBlockImporter::CustomLogger).to receive(:new).and_return(logger)
    allow(logger).to receive(:with_context).and_return(logger_with_context)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    allow(logger).to receive(:fatal)
    allow(logger_with_context).to receive(:info)
    allow(logger_with_context).to receive(:warn)
    allow(logger_with_context).to receive(:error)
    
    # Mock config methods
    allow(config).to receive(:log_level).and_return(:info)
    allow(config).to receive(:log_output).and_return(STDOUT)
    allow(config).to receive(:show_progress?).and_return(false)
    allow(config).to receive(:continue_on_error?).and_return(false)
    allow(config).to receive(:sitemap_recursive?).and_return(false)
    allow(config).to receive(:retries).and_return(3)
    allow(config).to receive(:follow_redirects?).and_return(true)
    allow(config).to receive(:warn_empty_content?).and_return(true)
    allow(config).to receive(:strip_newlines?).and_return(false)
    allow(config).to receive(:encode_quotes?).and_return(true)
    allow(config).to receive(:name_selector).and_return('h1')
    allow(config).to receive(:encode_title?).and_return(true)
    allow(config).to receive(:sitemap_max_depth).and_return(3)
    allow(config).to receive(:sitemap_same_domain_only?).and_return(false)
    allow(config).to receive(:create_directories?).and_return(true)
    allow(config).to receive(:use_domain_directories?).and_return(false)
    allow(config).to receive(:base_directory).and_return('.')
    allow(config).to receive(:filename_pattern).and_return('node-{index}.output.yml')
    allow(config).to receive(:sanitize_domain_names?).and_return(true)
  end

  describe '.run' do
    it 'creates a new instance and calls run' do
      cli_instance = instance_double('TextBlockImporter::CLI')
      allow(described_class).to receive(:new).with(['test']).and_return(cli_instance)
      allow(cli_instance).to receive(:run)
      
      described_class.run(['test'])
      
      expect(described_class).to have_received(:new).with(['test'])
      expect(cli_instance).to have_received(:run)
    end
  end

  describe '#initialize' do
    it 'initializes with args and sets up dependencies' do
      args = ['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml']
      cli = described_class.new(args)
      
      expect(cli.instance_variable_get(:@args)).to eq(args)
      expect(TextBlockImporter::Config).to have_received(:new).with(config_path: nil)
      expect(TextBlockImporter::CustomLogger).to have_received(:new)
    end

    it 'uses custom config path when provided' do
      args = ['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--config', 'custom.yml']
      described_class.new(args)
      
      expect(TextBlockImporter::Config).to have_received(:new).with(config_path: 'custom.yml')
    end
  end

  describe '#run' do
    context 'when version flag is provided' do
      it 'shows version and returns early with --version' do
        cli = described_class.new(['--version'])
        expect(cli).to receive(:show_version)
        
        cli.run
      end

      it 'shows version and returns early with -v' do
        cli = described_class.new(['-v'])
        expect(cli).to receive(:show_version)
        
        cli.run
      end
    end

    context 'when help flag is provided' do
      it 'shows help and returns early with --help' do
        cli = described_class.new(['--help'])
        expect(cli).to receive(:show_help)
        
        cli.run
      end

      it 'shows help and returns early with -h' do
        cli = described_class.new(['-h'])
        expect(cli).to receive(:show_help)
        
        cli.run
      end
    end

    context 'when no command is provided' do
      it 'shows help and exits with status 1' do
        cli = described_class.new([])
        expect(cli).to receive(:show_help)
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'when invalid command is provided' do
      it 'shows help and exits with status 1' do
        cli = described_class.new(['invalid_command'])
        expect(cli).to receive(:show_help)
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'when TextBlockImporter::Error is raised' do
      it 'outputs error message to STDERR and exits with status 1' do
        cli = described_class.new(['scrape'])
        allow(cli).to receive(:scrape_single).and_raise(TextBlockImporter::Error.new('Test error'))
        
        expect(STDERR).to receive(:puts).with('Error: Test error')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'when scrape command is provided' do
      it 'calls scrape_single method' do
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml'])
        expect(cli).to receive(:scrape_single)
        
        cli.run
      end
    end

    context 'when batch command is provided' do
      it 'calls batch_process method' do
        cli = described_class.new(['batch', 'urls.txt', '.content', 'template.yml'])
        expect(cli).to receive(:batch_process)
        
        cli.run
      end
    end

    context 'when extract-urls command is provided' do
      it 'calls extract_urls method' do
        cli = described_class.new(['extract-urls', 'http://example.com', 'a'])
        expect(cli).to receive(:extract_urls)
        
        cli.run
      end
    end

    context 'when sitemap command is provided' do
      it 'calls process_sitemap method' do
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml'])
        expect(cli).to receive(:process_sitemap)
        
        cli.run
      end
    end
  end

  describe 'argument validation' do
    describe 'scrape command' do
      it 'validates all required arguments are present' do
        cli = described_class.new(['scrape'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer scrape <url> <selector> <template> <output>')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'validates url argument is present' do
        cli = described_class.new(['scrape', nil, '.content', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer scrape <url> <selector> <template> <output>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates selector argument is present' do
        cli = described_class.new(['scrape', 'http://example.com', nil, 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer scrape <url> <selector> <template> <output>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates template argument is present' do
        cli = described_class.new(['scrape', 'http://example.com', '.content', nil, 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer scrape <url> <selector> <template> <output>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates output argument is present' do
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', nil])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer scrape <url> <selector> <template> <output>')
        expect { cli.run }.to raise_error(SystemExit)
      end
    end

    describe 'batch command' do
      it 'validates all required arguments are present' do
        cli = described_class.new(['batch'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer batch <url_file> <selector> <template>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates url_file argument is present' do
        cli = described_class.new(['batch', nil, '.content', 'template.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer batch <url_file> <selector> <template>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates selector argument is present' do
        cli = described_class.new(['batch', 'urls.txt', nil, 'template.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer batch <url_file> <selector> <template>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates template argument is present' do
        cli = described_class.new(['batch', 'urls.txt', '.content', nil])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer batch <url_file> <selector> <template>')
        expect { cli.run }.to raise_error(SystemExit)
      end
    end

    describe 'extract-urls command' do
      it 'validates all required arguments are present' do
        cli = described_class.new(['extract-urls'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer extract-urls <url> <selector>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates url argument is present' do
        cli = described_class.new(['extract-urls', nil, 'a'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer extract-urls <url> <selector>')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates selector argument is present' do
        cli = described_class.new(['extract-urls', 'http://example.com', nil])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer extract-urls <url> <selector>')
        expect { cli.run }.to raise_error(SystemExit)
      end
    end

    describe 'sitemap command' do
      it 'validates sitemap_url argument is present' do
        cli = described_class.new(['sitemap'])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer sitemap <sitemap_url> [--output filename]')
        expect { cli.run }.to raise_error(SystemExit)
      end

      it 'validates sitemap_url argument is not empty' do
        cli = described_class.new(['sitemap', nil])
        
        expect(STDERR).to receive(:puts).with('Error: Missing required arguments')
        expect(STDERR).to receive(:puts).with('Usage: text_block_importer sitemap <sitemap_url> [--output filename]')
        expect { cli.run }.to raise_error(SystemExit)
      end
    end
  end

  describe 'option parsing' do
    let(:cli) { described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml']) }

    it 'parses --use-domains flag' do
      cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--use-domains'])
      options = cli.instance_variable_get(:@options)
      
      expect(options[:use_domains]).to be true
    end

    it 'parses --config flag with value' do
      cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--config', 'custom.yml'])
      options = cli.instance_variable_get(:@options)
      
      expect(options[:config]).to eq('custom.yml')
    end

    it 'parses --output flag with value' do
      cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml', '--output', 'custom.txt'])
      options = cli.instance_variable_get(:@options)
      
      expect(options[:output]).to eq('custom.txt')
    end

    it 'parses --verbose flag' do
      cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--verbose'])
      options = cli.instance_variable_get(:@options)
      
      expect(options[:verbose]).to be true
    end

    it 'parses -v flag as verbose' do
      cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '-v'])
      options = cli.instance_variable_get(:@options)
      
      expect(options[:verbose]).to be true
    end

    it 'handles multiple flags together' do
      cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--use-domains', '--verbose', '--config', 'test.yml'])
      options = cli.instance_variable_get(:@options)
      
      expect(options[:use_domains]).to be true
      expect(options[:verbose]).to be true
      expect(options[:config]).to eq('test.yml')
    end

    it 'removes parsed flags from args array' do
      args = ['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--use-domains', '--verbose']
      cli = described_class.new(args)
      final_args = cli.instance_variable_get(:@args)
      
      expect(final_args).not_to include('--use-domains')
      expect(final_args).not_to include('--verbose')
      expect(final_args).to include('scrape')
      expect(final_args).to include('http://example.com')
    end

    context 'when --config flag is missing value' do
      it 'does not set config option' do
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--config'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:config]).to be_nil
      end
    end

    context 'when --output flag is missing value' do
      it 'does not set output option' do
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml', '--output'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:output]).to be_nil
      end
    end
  end

  describe '#show_help' do
    it 'outputs comprehensive help text' do
      cli = described_class.new([])
      expect { cli.send(:show_help) }.to output(/Text Block Importer - Extract web content and convert to YAML/).to_stdout
    end

    it 'includes usage examples' do
      cli = described_class.new([])
      expect { cli.send(:show_help) }.to output(/Examples:/).to_stdout
    end

    it 'includes all command descriptions' do
      cli = described_class.new([])
      output = capture_stdout { cli.send(:show_help) }
      
      expect(output).to include('scrape')
      expect(output).to include('batch')
      expect(output).to include('extract-urls')
      expect(output).to include('sitemap')
    end

    it 'includes all option descriptions' do
      cli = described_class.new([])
      output = capture_stdout { cli.send(:show_help) }
      
      expect(output).to include('--use-domains')
      expect(output).to include('--output')
      expect(output).to include('--config')
      expect(output).to include('--verbose')
    end
  end

  describe '#show_version' do
    it 'outputs the version number' do
      cli = described_class.new([])
      expect { cli.send(:show_version) }.to output("#{TextBlockImporter::VERSION}\n").to_stdout
    end
  end

  describe 'command execution integration' do
    let(:scraper) { instance_double('TextBlockImporter::Scraper') }
    let(:generator) { instance_double('TextBlockImporter::YamlGenerator') }
    let(:path_helper) { instance_double('TextBlockImporter::PathHelper') }
    let(:sitemap_parser) { instance_double('TextBlockImporter::SitemapParser') }
    let(:url_extractor) { instance_double('TextBlockImporter::UrlExtractor') }

    before do
      allow(TextBlockImporter::Scraper).to receive(:new).and_return(scraper)
      allow(TextBlockImporter::YamlGenerator).to receive(:new).and_return(generator)
      allow(TextBlockImporter::PathHelper).to receive(:new).and_return(path_helper)
      allow(TextBlockImporter::SitemapParser).to receive(:new).and_return(sitemap_parser)
      allow(TextBlockImporter::UrlExtractor).to receive(:new).and_return(url_extractor)
      
      # Mock validator methods
      allow(TextBlockImporter::Validator).to receive(:validate_url!)
      allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
      allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
      allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
      allow(TextBlockImporter::Validator).to receive(:validate_file_exists!)
    end

    describe 'scrape command execution' do
      it 'executes scrape workflow successfully' do
        content = { 'title' => 'Test Page', 'content' => 'Test content' }
        yaml_content = 'test: yaml'
        
        allow(scraper).to receive(:scrape).with('http://example.com', '.content').and_return(content)
        allow(generator).to receive(:generate).with(content, hash_including(:use_domains => false)).and_return(yaml_content)
        allow(generator).to receive(:save).with(yaml_content, 'output.yml')
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml'])
        
        expect { cli.run }.to output(/Generated: output.yml/).to_stdout
        
        expect(TextBlockImporter::Validator).to have_received(:validate_url!).with('http://example.com')
        expect(TextBlockImporter::Validator).to have_received(:validate_css_selector!).with('.content')
        expect(TextBlockImporter::Validator).to have_received(:validate_template_file!).with('template.yml')
        expect(TextBlockImporter::Validator).to have_received(:validate_output_directory!).with('output.yml')
        expect(scraper).to have_received(:scrape).with('http://example.com', '.content')
        expect(generator).to have_received(:generate).with(content, hash_including(:use_domains => false))
        expect(generator).to have_received(:save).with(yaml_content, 'output.yml')
      end

      it 'passes use_domains option to generator' do
        content = { 'title' => 'Test Page' }
        allow(scraper).to receive(:scrape).and_return(content)
        allow(generator).to receive(:generate).and_return('yaml')
        allow(generator).to receive(:save)
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--use-domains'])
        cli.run
        
        expect(generator).to have_received(:generate).with(content, hash_including(:use_domains => true))
      end
    end

    describe 'batch command execution' do
      let(:temp_file) { create_temp_file(['http://example1.com', 'http://example2.com', '']) }
      
      after do
        File.unlink(temp_file) if File.exist?(temp_file)
      end

      it 'processes multiple URLs successfully' do
        content1 = { 'title' => 'Page 1' }
        content2 = { 'title' => 'Page 2' }
        
        allow(scraper).to receive(:scrape).with('http://example1.com', '.content').and_return(content1)
        allow(scraper).to receive(:scrape).with('http://example2.com', '.content').and_return(content2)
        allow(generator).to receive(:generate).and_return('yaml')
        allow(generator).to receive(:save)
        allow(path_helper).to receive(:build_batch_output_path).and_return('node-1.yml', 'node-2.yml')
        
        cli = described_class.new(['batch', temp_file, '.content', 'template.yml'])
        
        expect { cli.run }.to output(/Batch processing complete: 2 successful, 0 failed/).to_stdout
        
        expect(scraper).to have_received(:scrape).with('http://example1.com', '.content')
        expect(scraper).to have_received(:scrape).with('http://example2.com', '.content')
        expect(generator).to have_received(:save).twice
      end

      it 'handles empty URL file' do
        empty_file = create_temp_file(['', '  ', "\n"])
        
        cli = described_class.new(['batch', empty_file, '.content', 'template.yml'])
        
        expect { cli.run }.to output(/No URLs found in file/).to_stdout
        
        File.unlink(empty_file)
      end

      it 'shows progress when configured' do
        allow(config).to receive(:show_progress?).and_return(true)
        allow(scraper).to receive(:scrape).and_return({})
        allow(generator).to receive(:generate).and_return('yaml')
        allow(generator).to receive(:save)
        allow(path_helper).to receive(:build_batch_output_path).and_return('node-1.yml')
        
        cli = described_class.new(['batch', temp_file, '.content', 'template.yml'])
        
        expect { cli.run }.to output(/\[1\/2\] Processing: http:\/\/example1\.com/).to_stdout
      end

      it 'continues on error when configured' do
        allow(config).to receive(:continue_on_error?).and_return(true)
        allow(scraper).to receive(:scrape).with('http://example1.com', '.content').and_raise(StandardError.new('Network error'))
        allow(scraper).to receive(:scrape).with('http://example2.com', '.content').and_return({})
        allow(generator).to receive(:generate).and_return('yaml')
        allow(generator).to receive(:save)
        allow(path_helper).to receive(:build_batch_output_path).and_return('node-1.yml', 'node-2.yml')
        
        cli = described_class.new(['batch', temp_file, '.content', 'template.yml'])
        
        expect { cli.run }.to output(/Batch processing complete: 1 successful, 1 failed/).to_stdout
      end

      it 'stops on error when continue_on_error is false' do
        allow(config).to receive(:continue_on_error?).and_return(false)
        allow(scraper).to receive(:scrape).with('http://example1.com', '.content').and_raise(StandardError.new('Network error'))
        allow(path_helper).to receive(:build_batch_output_path).and_return('node-1.yml')
        
        cli = described_class.new(['batch', temp_file, '.content', 'template.yml'])
        
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    describe 'extract-urls command execution' do
      it 'extracts URLs and outputs them' do
        urls = ['http://example.com/page1', 'http://example.com/page2']
        allow(url_extractor).to receive(:extract).with('http://example.com', 'a').and_return(urls)
        
        cli = described_class.new(['extract-urls', 'http://example.com', 'a'])
        
        expect { cli.run }.to output("http://example.com/page1\nhttp://example.com/page2\n").to_stdout
        
        expect(url_extractor).to have_received(:extract).with('http://example.com', 'a')
      end

      it 'loads UrlExtractor class dynamically' do
        allow(url_extractor).to receive(:extract).and_return([])
        
        cli = described_class.new(['extract-urls', 'http://example.com', 'a'])
        
        expect(cli).to receive(:require_relative).with('url_extractor')
        cli.run
      end
    end

    describe 'sitemap command execution' do
      it 'processes sitemap successfully' do
        urls = ['http://example.com/page1', 'http://example.com/page2']
        output_file = 'sitemap.links'
        
        allow(sitemap_parser).to receive(:parse).with('http://example.com/sitemap.xml').and_return(urls)
        allow(path_helper).to receive(:build_sitemap_output_path).with('http://example.com/sitemap.xml', nil).and_return(output_file)
        allow(File).to receive(:write).with(output_file, urls.join("\n"))
        
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml'])
        
        expect { cli.run }.to output(/Retrieved 2 URLs to sitemap.links/).to_stdout
        
        expect(TextBlockImporter::Validator).to have_received(:validate_url!).with('http://example.com/sitemap.xml')
        expect(sitemap_parser).to have_received(:parse).with('http://example.com/sitemap.xml')
        expect(File).to have_received(:write).with(output_file, urls.join("\n"))
      end

      it 'uses custom output filename when provided' do
        urls = ['http://example.com/page1']
        custom_output = 'custom.txt'
        
        allow(sitemap_parser).to receive(:parse).and_return(urls)
        allow(path_helper).to receive(:build_sitemap_output_path).with('http://example.com/sitemap.xml', custom_output).and_return(custom_output)
        allow(File).to receive(:write)
        
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml', '--output', custom_output])
        cli.run
        
        expect(path_helper).to have_received(:build_sitemap_output_path).with('http://example.com/sitemap.xml', custom_output)
      end

      it 'shows recursive note when sitemap_recursive is enabled' do
        allow(config).to receive(:sitemap_recursive?).and_return(true)
        allow(sitemap_parser).to receive(:parse).and_return(['http://example.com/page1'])
        allow(path_helper).to receive(:build_sitemap_output_path).and_return('sitemap.links')
        allow(File).to receive(:write)
        
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml'])
        
        expect { cli.run }.to output(/Note: Recursive sitemap parsing was enabled/).to_stdout
      end
    end
  end

  describe 'error handling' do
    let(:scraper) { instance_double('TextBlockImporter::Scraper') }
    let(:generator) { instance_double('TextBlockImporter::YamlGenerator') }
    let(:path_helper) { instance_double('TextBlockImporter::PathHelper') }
    let(:sitemap_parser) { instance_double('TextBlockImporter::SitemapParser') }

    before do
      allow(TextBlockImporter::Scraper).to receive(:new).and_return(scraper)
      allow(TextBlockImporter::YamlGenerator).to receive(:new).and_return(generator)
      allow(TextBlockImporter::PathHelper).to receive(:new).and_return(path_helper)
      allow(TextBlockImporter::SitemapParser).to receive(:new).and_return(sitemap_parser)
    end

    describe 'validation errors' do
      it 'handles URL validation errors for scrape command' do
        allow(TextBlockImporter::Validator).to receive(:validate_url!).with('invalid-url').and_raise(TextBlockImporter::Error.new('Invalid URL'))
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
        
        cli = described_class.new(['scrape', 'invalid-url', '.content', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Invalid URL')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles CSS selector validation errors' do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!).with('invalid][selector').and_raise(TextBlockImporter::Error.new('Invalid CSS selector'))
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
        
        cli = described_class.new(['scrape', 'http://example.com', 'invalid][selector', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Invalid CSS selector')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles template file validation errors' do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!).with('nonexistent.yml').and_raise(TextBlockImporter::Error.new('Template file not found'))
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'nonexistent.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Template file not found')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles output directory validation errors' do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!).with('/readonly/output.yml').and_raise(TextBlockImporter::Error.new('Output directory not writable'))
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', '/readonly/output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Output directory not writable')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles file existence validation errors for batch command' do
        allow(TextBlockImporter::Validator).to receive(:validate_file_exists!).with('nonexistent.txt', 'URL file').and_raise(TextBlockImporter::Error.new('URL file does not exist'))
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        
        cli = described_class.new(['batch', 'nonexistent.txt', '.content', 'template.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: URL file does not exist')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    describe 'scraping errors' do
      before do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
      end

      it 'handles network errors during scraping' do
        allow(scraper).to receive(:scrape).and_raise(TextBlockImporter::Error.new('Connection timeout'))
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Connection timeout')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles content extraction errors' do
        allow(scraper).to receive(:scrape).and_raise(TextBlockImporter::Error.new('No content found with selector'))
        
        cli = described_class.new(['scrape', 'http://example.com', '.nonexistent', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: No content found with selector')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    describe 'file generation errors' do
      before do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
        allow(scraper).to receive(:scrape).and_return({})
      end

      it 'handles YAML generation errors' do
        allow(generator).to receive(:generate).and_raise(TextBlockImporter::Error.new('Template parsing failed'))
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Template parsing failed')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles file save errors' do
        allow(generator).to receive(:generate).and_return('yaml content')
        allow(generator).to receive(:save).and_raise(TextBlockImporter::Error.new('Permission denied writing file'))
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml'])
        
        expect(STDERR).to receive(:puts).with('Error: Permission denied writing file')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    describe 'sitemap errors' do
      before do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
      end

      it 'handles sitemap parsing errors' do
        allow(sitemap_parser).to receive(:parse).and_raise(TextBlockImporter::Error.new('Invalid XML format'))
        
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml'])
        
        expect(STDERR).to receive(:puts).with('Error: Invalid XML format')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles sitemap file write errors' do
        allow(sitemap_parser).to receive(:parse).and_return(['http://example.com/page1'])
        allow(path_helper).to receive(:build_sitemap_output_path).and_return('sitemap.links')
        allow(File).to receive(:write).and_raise(TextBlockImporter::Error.new('Disk full'))
        
        cli = described_class.new(['sitemap', 'http://example.com/sitemap.xml'])
        
        expect(STDERR).to receive(:puts).with('Error: Disk full')
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    describe 'configuration errors' do
      it 'handles missing config file errors during initialization' do
        allow(TextBlockImporter::Config).to receive(:new).and_raise(TextBlockImporter::Error.new('Config file not found'))
        
        # The CLI class itself doesn't catch initialization errors - they would be caught by the caller
        expect { described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml', '--config', 'missing.yml']) }.to raise_error(TextBlockImporter::Error, 'Config file not found')
      end

      it 'handles invalid config file format errors' do
        allow(TextBlockImporter::Config).to receive(:new).and_raise(TextBlockImporter::Error.new('Invalid YAML in config file'))
        
        # The CLI class itself doesn't catch initialization errors - they would be caught by the caller  
        expect { described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml']) }.to raise_error(TextBlockImporter::Error, 'Invalid YAML in config file')
      end
    end

    describe 'logger initialization errors' do
      it 'handles logger creation errors' do
        allow(TextBlockImporter::CustomLogger).to receive(:new).and_raise(TextBlockImporter::Error.new('Cannot write to log file'))
        
        # The CLI class itself doesn't catch initialization errors - they would be caught by the caller
        expect { described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml']) }.to raise_error(TextBlockImporter::Error, 'Cannot write to log file')
      end
    end

    describe 'batch processing errors' do
      let(:temp_file) { create_temp_file(['http://example.com']) }
      
      after do
        File.unlink(temp_file) if File.exist?(temp_file)
      end

      before do
        allow(TextBlockImporter::Validator).to receive(:validate_file_exists!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(path_helper).to receive(:build_batch_output_path).and_return('node-1.yml')
      end

      it 'handles URL file read errors' do
        allow(File).to receive(:readlines).and_raise(StandardError.new('Permission denied reading file'))
        
        cli = described_class.new(['batch', temp_file, '.content', 'template.yml'])
        
        # This error would be unhandled and would propagate up
        expect { cli.run }.to raise_error(StandardError, 'Permission denied reading file')
      end

      it 'handles individual URL processing errors when continue_on_error is false' do
        allow(config).to receive(:continue_on_error?).and_return(false)
        allow(File).to receive(:readlines).and_return(['http://example.com'])
        allow(scraper).to receive(:scrape).and_raise(StandardError.new('Network error'))
        
        cli = described_class.new(['batch', temp_file, '.content', 'template.yml'])
        
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
        
        expect(logger).to have_received(:fatal).with('Stopping batch processing due to error')
      end
    end

    describe 'exit codes' do
      it 'exits with code 1 for validation errors' do
        allow(TextBlockImporter::Validator).to receive(:validate_url!).and_raise(TextBlockImporter::Error.new('Invalid URL'))
        
        cli = described_class.new(['scrape', 'invalid', '.content', 'template.yml', 'output.yml'])
        
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'exits with code 1 for runtime errors' do
        allow(TextBlockImporter::Validator).to receive(:validate_url!)
        allow(TextBlockImporter::Validator).to receive(:validate_css_selector!)
        allow(TextBlockImporter::Validator).to receive(:validate_template_file!)
        allow(TextBlockImporter::Validator).to receive(:validate_output_directory!)
        allow(scraper).to receive(:scrape).and_raise(TextBlockImporter::Error.new('Network error'))
        
        cli = described_class.new(['scrape', 'http://example.com', '.content', 'template.yml', 'output.yml'])
        
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'exits with code 1 for missing arguments' do
        cli = described_class.new(['scrape'])
        
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'exits with code 1 for invalid commands' do
        cli = described_class.new(['invalid_command'])
        
        expect { cli.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end
  end

  private

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def create_temp_file(lines)
    file = Tempfile.new('test_urls')
    file.write(lines.join("\n"))
    file.close
    file.path
  end
end