# frozen_string_literal: true

require 'logger'

module TextBlockImporter
  class CustomLogger
    LEVELS = {
      debug: Logger::DEBUG,
      info: Logger::INFO,
      warn: Logger::WARN,
      error: Logger::ERROR,
      fatal: Logger::FATAL
    }.freeze
    
    def initialize(level: :info, output: $stdout)
      @logger = Logger.new(output)
      @logger.level = LEVELS[level]
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
        "[#{timestamp}] #{severity}: #{msg}\n"
      end
    end
    
    def debug(message)
      @logger.debug(message)
    end
    
    def info(message)
      @logger.info(message)
    end
    
    def warn(message)
      @logger.warn(message)
    end
    
    def error(message)
      @logger.error(message)
    end
    
    def fatal(message)
      @logger.fatal(message)
    end
    
    def with_context(context)
      ContextualLogger.new(@logger, context)
    end
  end
  
  class ContextualLogger
    def initialize(logger, context)
      @logger = logger
      @context = context
    end
    
    %i[debug info warn error fatal].each do |level|
      define_method(level) do |message|
        @logger.public_send(level, "[#{@context}] #{message}")
      end
    end
  end
end