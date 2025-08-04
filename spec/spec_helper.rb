# frozen_string_literal: true

# SimpleCov temporarily disabled due to CI issues
# TODO: Re-enable SimpleCov once CI issues are resolved
# if ENV['COVERAGE'] || ENV['CI']
#   require 'simplecov'
#   SimpleCov.start do
#     # SimpleCov configuration...
#   end
# end

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
  
  # Helper method to suppress STDERR for specific tests that produce expected error output
  def suppress_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original_stderr
  end
end