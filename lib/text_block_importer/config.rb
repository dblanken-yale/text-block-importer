# frozen_string_literal: true

require 'yaml'

module TextBlockImporter
  class Config
    DEFAULT_CONFIG_PATHS = [
      File.expand_path('../../config/default.yml', __dir__),
      File.expand_path('~/.text_block_importer.yml'),
      './text_block_importer.yml'
    ].freeze
    
    attr_reader :data
    
    def initialize(config_path: nil)
      @data = load_config(config_path)
    end
    
    def http
      data.dig('http') || {}
    end
    
    def logging
      data.dig('logging') || {}
    end
    
    def processing
      data.dig('processing') || {}
    end
    
    def templates
      data.dig('templates') || {}
    end
    
    def batch
      data.dig('batch') || {}
    end
    
    def output
      data.dig('output') || {}
    end
    
    # HTTP settings
    def user_agent
      http['user_agent'] || 'TextBlockImporter/2.0'
    end
    
    def timeout
      http['timeout'] || 30
    end
    
    def retries
      http['retries'] || 3
    end
    
    def follow_redirects?
      http.fetch('follow_redirects', true)
    end
    
    # Logging settings
    def log_level
      (logging['level'] || 'info').to_sym
    end
    
    def log_output
      output = logging['output'] || 'stdout'
      case output
      when 'stdout' then $stdout
      when 'stderr' then $stderr
      else File.open(output, 'a')
      end
    end
    
    # Processing settings
    def strip_newlines?
      processing.fetch('strip_newlines', true)
    end
    
    def encode_quotes?
      processing.fetch('encode_quotes', true)
    end
    
    def warn_empty_content?
      processing.fetch('warn_empty_content', true)
    end
    
    # Template settings
    def name_selector
      templates.dig('tokens', 'name_selector') || 'h1'
    end
    
    def encode_title?
      templates.dig('tokens', 'encode_title') != false
    end
    
    # Batch settings
    def show_progress?
      batch.fetch('show_progress', true)
    end
    
    def continue_on_error?
      batch.fetch('continue_on_error', true)
    end
    
    def filename_pattern
      output['filename_pattern'] || 'node-{index}.output.yml'
    end
    
    def create_directories?
      output.fetch('create_directories', true)
    end
    
    def base_directory
      output['base_directory'] || 'output'
    end
    
    def use_domain_directories?
      output.fetch('use_domain_directories', true)
    end
    
    def sanitize_domain_names?
      output.fetch('sanitize_domain_names', true)
    end
    
    # Sitemap settings
    def sitemap_recursive?
      sitemap.fetch('recursive', true)
    end
    
    def sitemap_max_depth
      sitemap['max_depth'] || 3
    end
    
    def sitemap_same_domain_only?
      sitemap.fetch('same_domain_only', true)
    end
    
    def sitemap
      data.dig('sitemap') || {}
    end
    
    private
    
    def load_config(config_path)
      config_files = config_path ? [config_path] : DEFAULT_CONFIG_PATHS
      
      merged_config = {}
      
      config_files.each do |path|
        next unless File.exist?(path)
        
        config_data = YAML.load_file(path)
        merged_config = deep_merge(merged_config, config_data) if config_data.is_a?(Hash)
      end
      
      merged_config
    end
    
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
end