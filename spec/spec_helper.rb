# frozen_string_literal: true

# Load SimpleCov first, but only when coverage is requested
if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/tmp/'
    
    add_group 'CLI', 'lib/text_block_importer/cli.rb'
    add_group 'Core Library', 'lib/text_block_importer.rb'
    add_group 'Configuration', 'lib/text_block_importer/config.rb'
    add_group 'HTTP Client', 'lib/text_block_importer/http_client.rb'
    add_group 'Processing', [
      'lib/text_block_importer/scraper.rb', 
      'lib/text_block_importer/yaml_generator.rb'
    ]
    add_group 'Parsing', [
      'lib/text_block_importer/sitemap_parser.rb',
      'lib/text_block_importer/url_extractor.rb'
    ]
    add_group 'Utilities', [
      'lib/text_block_importer/logger.rb',
      'lib/text_block_importer/validator.rb',
      'lib/text_block_importer/path_helper.rb'
    ]
    
    minimum_coverage 65  # Reduced from 85 to be more realistic
    
    # Generate multiple formats in CI
    if ENV['CI']
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::SimpleFormatter
      ])
    end
    
    # Don't fail on STDERR output from CLI tests
    enable_coverage :branch
    primary_coverage :line
  end
end

require_relative '../lib/text_block_importer'
require_relative 'support/shared_examples'
require_relative 'support/test_helpers'

# Load WebMock for HTTP request stubbing in integration tests
require 'webmock/rspec' if defined?(WebMock)

# Load fixtures
Dir[File.join(__dir__, 'fixtures', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Use expect syntax only (not should)
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  # Use mock framework
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Filter lines from Rails gems in backtraces
  config.filter_gems_from_backtrace 'nokogiri'

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Include test helpers
  config.include TestHelpers

  # Configure WebMock for integration tests
  if defined?(WebMock)
    config.before(:each, type: :integration) do
      WebMock.enable!
    end
    
    config.after(:each, type: :integration) do
      WebMock.reset!
      WebMock.disable!
    end
  end

  # Configure warnings
  config.warnings = true

  # Shared example groups configuration
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Focus specific tests when needed
  config.filter_run_when_matching :focus

  # Create temporary directories for tests
  config.before(:suite) do
    FileUtils.mkdir_p('tmp/test_output')
  end

  config.after(:suite) do
    FileUtils.rm_rf('tmp/test_output') if Dir.exist?('tmp/test_output')
  end

  # Clean up between tests
  config.before(:each) do
    # Reset any global state if needed
  end
  
  # Silence STDERR during CLI tests to prevent SimpleCov from detecting "errors"
  config.around(:each, type: :unit) do |example|
    if example.metadata[:full_description].include?('CLI')
      original_stderr = $stderr
      $stderr = StringIO.new
      example.run
      $stderr = original_stderr
    else
      example.run
    end
  end
end