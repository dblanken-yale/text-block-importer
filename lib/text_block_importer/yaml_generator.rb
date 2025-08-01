# frozen_string_literal: true

require 'securerandom'
require 'uri'
require 'fileutils'

module TextBlockImporter
  class YamlGenerator
    def initialize(template_path, config = Config.new, logger = nil)
      @template_content = File.read(template_path)
      @config = config
      @logger = logger
    end
    
    def generate(scraped_content, options = {})
      replacements = build_replacements(scraped_content, options)
      
      content = @template_content.dup
      replacements.each do |placeholder, value|
        if value
          content.gsub!(placeholder, value.to_s)
        else
          $stderr.puts "Could not replace for #{placeholder}"
        end
      end
      
      content
    end
    
    def save(yaml_content, output_path)
      # Create output directory if needed
      if @config.create_directories?
        dir = File.dirname(output_path)
        unless Dir.exist?(dir)
          begin
            FileUtils.mkdir_p(dir)
          rescue Errno::EEXIST => e
            # Re-raise as ENOTDIR if we can't create directory because parent is a file
            raise Errno::ENOTDIR, e.message
          end
        end
      end
      
      @logger&.debug("Writing YAML to: #{output_path}")
      File.write(output_path, yaml_content)
    end
    
    private
    
    def build_replacements(scraped_content, options)
      content = options[:use_domains] ? scraped_content.process_relative_urls : scraped_content.content
      web_page_file_name = File.basename(URI.parse(scraped_content.url).path) || ""
      
      {
        "{NAME}" => scraped_content.title,
        "{URL}" => "/#{web_page_file_name}",
        "{UUID}" => SecureRandom.uuid,
        "{BLOCK_UUID}" => SecureRandom.uuid,
        "{REPLACEME}" => content,
        "{SOURCE_URL}" => scraped_content.url
      }
    end
  end
end