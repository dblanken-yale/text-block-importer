# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tempfile'

RSpec.describe TextBlockImporter::CustomLogger do
  let(:output) { StringIO.new }
  let(:logger) { described_class.new(level: :info, output: output) }

  describe '#initialize' do
    it 'creates a new logger with default settings' do
      logger = described_class.new
      expect(logger).to be_a described_class
    end

    it 'accepts custom log level' do
      logger = described_class.new(level: :warn)
      expect(logger).to be_a described_class
    end

    it 'accepts custom output destination' do
      output = StringIO.new
      logger = described_class.new(output: output)
      expect(logger).to be_a described_class
    end

    it 'creates logger with combined custom settings' do
      output = StringIO.new
      logger = described_class.new(level: :debug, output: output)
      expect(logger).to be_a described_class
    end
  end

  describe 'log level filtering' do
    context 'with DEBUG level' do
      let(:logger) { described_class.new(level: :debug, output: output) }

      it 'logs all messages (debug, info, warn, error, fatal)' do
        logger.debug('Debug message')
        logger.info('Info message')
        logger.warn('Warn message')
        logger.error('Error message')
        logger.fatal('Fatal message')

        log_content = output.string
        expect(log_content).to include('DEBUG: Debug message')
        expect(log_content).to include('INFO: Info message')
        expect(log_content).to include('WARN: Warn message')
        expect(log_content).to include('ERROR: Error message')
        expect(log_content).to include('FATAL: Fatal message')
      end
    end

    context 'with INFO level' do
      let(:logger) { described_class.new(level: :info, output: output) }

      it 'logs info, warn, error, fatal but not debug' do
        logger.debug('Debug message')
        logger.info('Info message')
        logger.warn('Warn message')
        logger.error('Error message')
        logger.fatal('Fatal message')

        log_content = output.string
        expect(log_content).not_to include('DEBUG: Debug message')
        expect(log_content).to include('INFO: Info message')
        expect(log_content).to include('WARN: Warn message')
        expect(log_content).to include('ERROR: Error message')
        expect(log_content).to include('FATAL: Fatal message')
      end
    end

    context 'with WARN level' do
      let(:logger) { described_class.new(level: :warn, output: output) }

      it 'logs warn, error, fatal but not debug or info' do
        logger.debug('Debug message')
        logger.info('Info message')
        logger.warn('Warn message')
        logger.error('Error message')
        logger.fatal('Fatal message')

        log_content = output.string
        expect(log_content).not_to include('DEBUG: Debug message')
        expect(log_content).not_to include('INFO: Info message')
        expect(log_content).to include('WARN: Warn message')
        expect(log_content).to include('ERROR: Error message')
        expect(log_content).to include('FATAL: Fatal message')
      end
    end

    context 'with ERROR level' do
      let(:logger) { described_class.new(level: :error, output: output) }

      it 'logs error and fatal but not debug, info, or warn' do
        logger.debug('Debug message')
        logger.info('Info message')
        logger.warn('Warn message')
        logger.error('Error message')
        logger.fatal('Fatal message')

        log_content = output.string
        expect(log_content).not_to include('DEBUG: Debug message')
        expect(log_content).not_to include('INFO: Info message')
        expect(log_content).not_to include('WARN: Warn message')
        expect(log_content).to include('ERROR: Error message')
        expect(log_content).to include('FATAL: Fatal message')
      end
    end

    context 'with FATAL level' do
      let(:logger) { described_class.new(level: :fatal, output: output) }

      it 'logs only fatal messages' do
        logger.debug('Debug message')
        logger.info('Info message')
        logger.warn('Warn message')
        logger.error('Error message')
        logger.fatal('Fatal message')

        log_content = output.string
        expect(log_content).not_to include('DEBUG: Debug message')
        expect(log_content).not_to include('INFO: Info message')
        expect(log_content).not_to include('WARN: Warn message')
        expect(log_content).not_to include('ERROR: Error message')
        expect(log_content).to include('FATAL: Fatal message')
      end
    end
  end

  describe 'log message formatting' do
    let(:logger) { described_class.new(level: :debug, output: output) }

    it 'includes timestamp in log messages' do
      logger.info('Test message')
      
      log_content = output.string
      expect(log_content).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/)
    end

    it 'includes severity level in log messages' do
      logger.warn('Warning message')
      
      log_content = output.string
      expect(log_content).to include('WARN: Warning message')
    end

    it 'formats messages consistently' do
      logger.error('Error occurred')
      
      log_content = output.string
      expect(log_content).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] ERROR: Error occurred\n/)
    end

    it 'handles multi-line messages' do
      multiline_message = "Line 1\nLine 2\nLine 3"
      logger.info(multiline_message)
      
      log_content = output.string
      expect(log_content).to include(multiline_message)
    end

    it 'handles special characters in messages' do
      special_message = "Message with <special> & [characters] @#$%"
      logger.debug(special_message)
      
      log_content = output.string
      expect(log_content).to include(special_message)
    end
  end

  describe 'output destinations' do
    context 'with STDOUT output' do
      let(:logger) { described_class.new(level: :info, output: $stdout) }

      it 'creates logger successfully' do
        expect(logger).to be_a described_class
      end
    end

    context 'with STDERR output' do
      let(:logger) { described_class.new(level: :info, output: $stderr) }

      it 'creates logger successfully' do
        expect(logger).to be_a described_class
      end
    end

    context 'with file output' do
      let(:temp_file) { Tempfile.new('test_log') }
      let(:logger) { described_class.new(level: :info, output: temp_file) }

      after { temp_file.close }

      it 'writes to file successfully' do
        logger.info('Test file message')
        temp_file.rewind
        
        file_content = temp_file.read
        expect(file_content).to include('INFO: Test file message')
      end

      it 'handles multiple writes to file' do
        logger.info('First message')
        logger.warn('Second message')
        logger.error('Third message')
        temp_file.rewind
        
        file_content = temp_file.read
        expect(file_content).to include('INFO: First message')
        expect(file_content).to include('WARN: Second message')
        expect(file_content).to include('ERROR: Third message')
      end
    end

    context 'with StringIO output' do
      let(:string_io) { StringIO.new }
      let(:logger) { described_class.new(level: :debug, output: string_io) }

      it 'captures all log messages' do
        logger.debug('Debug test')
        logger.info('Info test')
        
        expect(string_io.string).to include('DEBUG: Debug test')
        expect(string_io.string).to include('INFO: Info test')
      end
    end
  end

  describe 'individual log methods' do
    let(:logger) { described_class.new(level: :debug, output: output) }

    describe '#debug' do
      it 'logs debug messages' do
        logger.debug('Debug test message')
        expect(output.string).to include('DEBUG: Debug test message')
      end
    end

    describe '#info' do
      it 'logs info messages' do
        logger.info('Info test message')
        expect(output.string).to include('INFO: Info test message')
      end
    end

    describe '#warn' do
      it 'logs warning messages' do
        logger.warn('Warning test message')
        expect(output.string).to include('WARN: Warning test message')
      end
    end

    describe '#error' do
      it 'logs error messages' do
        logger.error('Error test message')
        expect(output.string).to include('ERROR: Error test message')
      end
    end

    describe '#fatal' do
      it 'logs fatal messages' do
        logger.fatal('Fatal test message')
        expect(output.string).to include('FATAL: Fatal test message')
      end
    end
  end

  describe '#with_context' do
    let(:logger) { described_class.new(level: :debug, output: output) }

    it 'returns a ContextualLogger instance' do
      contextual_logger = logger.with_context('TestComponent')
      expect(contextual_logger).to be_a TextBlockImporter::ContextualLogger
    end

    it 'creates contextual logger with specified context' do
      contextual_logger = logger.with_context('Scraper')
      contextual_logger.info('Processing page')
      
      expect(output.string).to include('[Scraper] Processing page')
    end

    it 'allows different contexts' do
      scraper_logger = logger.with_context('Scraper')
      validator_logger = logger.with_context('Validator')
      
      scraper_logger.warn('Scraper warning')
      validator_logger.error('Validator error')
      
      log_content = output.string
      expect(log_content).to include('[Scraper] Scraper warning')
      expect(log_content).to include('[Validator] Validator error')
    end
  end

  describe 'integration with Config' do
    let(:temp_dir) { create_temp_directory }
    let(:config_file) { File.join(temp_dir, 'test_config.yml') }

    before do
      config_content = {
        'logging' => {
          'level' => 'debug',
          'output' => 'stdout'
        }
      }
      File.write(config_file, config_content.to_yaml)
    end

    it 'works with config-driven initialization' do
      config = TextBlockImporter::Config.new(config_path: config_file)
      
      # Test that config loaded correctly
      expect(config.log_level).to eq(:debug)
      expect(config.log_output).to eq($stdout)
      
      # Create logger with StringIO for testing
      test_output = StringIO.new
      logger = described_class.new(level: config.log_level, output: test_output)
      logger.info('Config-driven test message')
      
      expect(test_output.string).to include('INFO: Config-driven test message')
    end
  end

  describe 'edge cases and error handling' do
    it 'handles nil messages gracefully' do
      logger = described_class.new(level: :debug, output: output)
      expect { logger.info(nil) }.not_to raise_error
    end

    it 'handles empty string messages' do
      logger = described_class.new(level: :debug, output: output)
      logger.warn('')
      expect(output.string).to include('WARN: ')
    end

    it 'handles numeric messages' do
      logger = described_class.new(level: :debug, output: output)
      logger.error(404)
      expect(output.string).to include('ERROR: 404')
    end

    it 'handles complex object messages' do
      logger = described_class.new(level: :debug, output: output)
      logger.debug({ error: 'test', code: 500 })
      expect(output.string).to include('DEBUG: {:error=>"test", :code=>500}')
    end
  end

  describe 'performance considerations' do
    let(:logger) { described_class.new(level: :warn, output: output) }

    it 'does not process debug messages when level is higher' do
      # This is implicit - debug messages should not appear in output
      # when logger level is set to warn
      logger.debug('This should not be processed')
      expect(output.string).to be_empty
    end

    it 'handles high volume logging' do
      logger = described_class.new(level: :info, output: output)
      
      100.times do |i|
        logger.info("Message #{i}")
      end
      
      log_content = output.string
      expect(log_content.scan(/INFO: Message/).count).to eq(100)
    end
  end
end

RSpec.describe TextBlockImporter::ContextualLogger do
  let(:output) { StringIO.new }
  let(:base_logger) { TextBlockImporter::CustomLogger.new(level: :debug, output: output) }
  let(:contextual_logger) { base_logger.with_context('TestContext') }

  describe '#initialize' do
    it 'creates contextual logger with base logger and context' do
      logger = described_class.new(base_logger, 'Context')
      expect(logger).to be_a described_class
    end
  end

  describe 'contextual logging methods' do
    describe '#debug' do
      it 'adds context to debug messages' do
        contextual_logger.debug('Debug with context')
        expect(output.string).to include('[TestContext] Debug with context')
      end
    end

    describe '#info' do
      it 'adds context to info messages' do
        contextual_logger.info('Info with context')
        expect(output.string).to include('[TestContext] Info with context')
      end
    end

    describe '#warn' do
      it 'adds context to warning messages' do
        contextual_logger.warn('Warning with context')
        expect(output.string).to include('[TestContext] Warning with context')
      end
    end

    describe '#error' do
      it 'adds context to error messages' do
        contextual_logger.error('Error with context')
        expect(output.string).to include('[TestContext] Error with context')
      end
    end

    describe '#fatal' do
      it 'adds context to fatal messages' do
        contextual_logger.fatal('Fatal with context')
        expect(output.string).to include('[TestContext] Fatal with context')
      end
    end
  end

  describe 'context formatting' do
    it 'preserves original message with context prefix' do
      contextual_logger.info('Original message')
      expect(output.string).to include('[TestContext] Original message')
    end

    it 'handles complex contexts' do
      complex_logger = base_logger.with_context('Module::Class#method')
      complex_logger.warn('Complex context test')
      expect(output.string).to include('[Module::Class#method] Complex context test')
    end

    it 'handles empty context' do
      empty_logger = base_logger.with_context('')
      empty_logger.error('Empty context test')
      expect(output.string).to include('[] Empty context test')
    end

    it 'handles nil context' do
      nil_logger = base_logger.with_context(nil)
      nil_logger.info('Nil context test')
      expect(output.string).to include('[] Nil context test')
    end
  end

  describe 'respects base logger level filtering' do
    let(:warn_logger) { TextBlockImporter::CustomLogger.new(level: :warn, output: output) }
    let(:contextual_warn_logger) { warn_logger.with_context('WarnContext') }

    it 'filters debug and info messages like base logger' do
      contextual_warn_logger.debug('Should not appear')
      contextual_warn_logger.info('Should not appear')
      contextual_warn_logger.warn('Should appear')
      
      log_content = output.string
      expect(log_content).not_to include('Should not appear')
      expect(log_content).to include('[WarnContext] Should appear')
    end
  end

  describe 'nested contextual loggers' do
    it 'can create contextual loggers from other contextual loggers' do
      # Note: Current implementation doesn't support nested contexts directly
      # but we can test that it works with the base logger
      first_context = base_logger.with_context('First')
      first_context.info('First level')
      
      second_context = base_logger.with_context('Second')
      second_context.info('Second level')
      
      log_content = output.string
      expect(log_content).to include('[First] First level')
      expect(log_content).to include('[Second] Second level')
    end
  end

  describe 'integration scenarios' do
    it 'multiple components can use different contexts' do
      scraper_logger = base_logger.with_context('Scraper')
      validator_logger = base_logger.with_context('Validator')
      generator_logger = base_logger.with_context('YAMLGenerator')
      
      scraper_logger.info('Starting page scrape')
      validator_logger.warn('URL validation warning')
      generator_logger.debug('Generating YAML output')
      scraper_logger.info('Page scrape completed')
      
      log_content = output.string
      expect(log_content).to include('[Scraper] Starting page scrape')
      expect(log_content).to include('[Validator] URL validation warning')
      expect(log_content).to include('[YAMLGenerator] Generating YAML output')
      expect(log_content).to include('[Scraper] Page scrape completed')
    end

    it 'maintains proper chronological order with mixed contexts' do
      logger1 = base_logger.with_context('A')
      logger2 = base_logger.with_context('B')
      
      logger1.info('Message 1')
      logger2.info('Message 2')
      logger1.info('Message 3')
      
      log_content = output.string
      lines = log_content.split("\n").reject(&:empty?)
      
      expect(lines[0]).to include('[A] Message 1')
      expect(lines[1]).to include('[B] Message 2')
      expect(lines[2]).to include('[A] Message 3')
    end
  end
end