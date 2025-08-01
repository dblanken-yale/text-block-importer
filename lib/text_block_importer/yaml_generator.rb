require 'securerandom'
require 'uri'

module TextBlockImporter
  class YamlGenerator
    def initialize(template_path)
      @template_content = File.read(template_path)
    end
    
    def generate(scraped_content, options = {})
      replacements = build_replacements(scraped_content, options)
      
      content = @template_content.dup
      replacements.each do |placeholder, value|
        if value
          content.gsub!(placeholder, value.to_s)
        else
          STDERR.puts "Could not replace for #{placeholder}"
        end
      end
      
      content
    end
    
    def save(yaml_content, output_path)
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