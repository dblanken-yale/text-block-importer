# frozen_string_literal: true

require 'uri'

module TextBlockImporter
  class ValidationError < StandardError; end
  
  class Validator
    URL_REGEX = /\Ahttps?:\/\/[^\s]+\z/
    CSS_SELECTOR_REGEX = /\A[a-zA-Z0-9\s\-_#.:,>\[\]"'=()]+\z/
    
    def self.validate_url!(url)
      raise ValidationError, "URL cannot be empty" if url.nil? || url.strip.empty?
      raise ValidationError, "Invalid URL format: #{url}" unless url.match?(URL_REGEX)
      
      begin
        uri = URI.parse(url)
        raise ValidationError, "URL must have a host" unless uri.host
      rescue URI::InvalidURIError => e
        raise ValidationError, "Invalid URL: #{e.message}"
      end
    end
    
    def self.validate_css_selector!(selector)
      raise ValidationError, "CSS selector cannot be empty" if selector.nil? || selector.strip.empty?
      raise ValidationError, "Invalid CSS selector format" unless selector.match?(CSS_SELECTOR_REGEX)
    end
    
    def self.validate_file_exists!(file_path, file_type = 'file')
      raise ValidationError, "#{file_type.capitalize} path cannot be empty" if file_path.nil? || file_path.strip.empty?
      raise ValidationError, "#{file_type.capitalize} not found: #{file_path}" unless File.exist?(file_path)
    end
    
    def self.validate_template_file!(template_path)
      validate_file_exists!(template_path, 'template file')
      
      content = File.read(template_path)
      required_tokens = %w[{UUID} {BLOCK_UUID} {REPLACEME}]
      
      missing_tokens = required_tokens.reject { |token| content.include?(token) }
      return if missing_tokens.empty?
      
      raise ValidationError, "Template missing required tokens: #{missing_tokens.join(', ')}"
    end
    
    def self.validate_output_directory!(output_path)
      dir = File.dirname(output_path)
      return if Dir.exist?(dir)
      
      raise ValidationError, "Output directory does not exist: #{dir}"
    end
  end
end