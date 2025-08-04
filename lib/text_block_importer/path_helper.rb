# frozen_string_literal: true

require 'uri'
require 'fileutils'

module TextBlockImporter
  class PathHelper
    def initialize(config, logger = nil)
      @config = config
      @logger = logger
    end
    
    def build_output_path(url, filename = nil)
      if @config.use_domain_directories?
        domain = extract_domain(url)
        sanitized_domain = sanitize_domain(domain)
        directory = File.join(@config.base_directory, sanitized_domain)
      else
        directory = @config.base_directory
      end
      
      ensure_directory_exists(directory)
      
      if filename
        File.join(directory, filename)
      else
        directory
      end
    end
    
    def build_sitemap_output_path(url, custom_filename = nil)
      filename = custom_filename || 'sitemap.links'
      build_output_path(url, filename)
    end
    
    def build_batch_output_path(base_url, index)
      filename = @config.filename_pattern.gsub('{index}', index.to_s)
      build_output_path(base_url, filename)
    end
    
    private
    
    def extract_domain(url)
      parsed_uri = URI.parse(url)
      return 'unknown-domain' if parsed_uri.host.nil? || parsed_uri.host.empty?
      parsed_uri.host
    rescue URI::InvalidURIError
      @logger&.warn("Invalid URL for domain extraction: #{url}")
      'unknown-domain'
    end
    
    def sanitize_domain(domain)
      return domain unless @config.sanitize_domain_names?
      return 'empty-domain' if domain.nil? || domain.empty?
      
      # Replace characters that aren't filesystem-safe
      sanitized = domain.gsub(/[^\w.-]/, '_')
      # Remove leading/trailing dots and underscores
      result = sanitized.gsub(/^[._]+|[._]+$/, '')
      result.empty? ? 'sanitized-domain' : result
    end
    
    def ensure_directory_exists(directory)
      return if Dir.exist?(directory)
      
      if @config.create_directories?
        @logger&.debug("Creating directory: #{directory}")
        FileUtils.mkdir_p(directory)
      else
        raise ValidationError, "Output directory does not exist: #{directory}"
      end
    end
  end
end