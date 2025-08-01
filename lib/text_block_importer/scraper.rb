# frozen_string_literal: true

require 'nokogiri'
require 'uri'

module TextBlockImporter
  class Scraper
    def initialize(config = Config.new, logger = nil)
      @config = config
      @logger = logger
      @http_client = HttpClient.new(config, logger)
    end
    
    def scrape(url, selector, options = {})
      html = @http_client.fetch(url)
      doc = Nokogiri::HTML(html)
      
      content = extract_content(doc, selector)
      title = extract_title(doc)
      
      ScrapedContent.new(
        content: content,
        title: title,
        url: url,
        domain: extract_domain(url)
      )
    rescue => e
      raise SelectorError, "Failed to scrape #{url} with selector '#{selector}': #{e.message}"
    end
    
    private
    
    def extract_content(doc, selector)
      element = doc.at(selector)
      return '' unless element
      
      # Check if the element has meaningful text content
      if element.text.strip.empty?
        if @config.warn_empty_content?
          warning = "No data found for selector '#{selector}'"
          @logger&.warn(warning)
          $stderr.puts("Warning: #{warning}")
        end
        return ''
      end
      
      content = element.to_s.strip
      content = content.gsub("\n", "") if @config.strip_newlines?
      content = content.gsub("'", "&#39;") if @config.encode_quotes?
      
      content
    end
    
    def extract_title(doc)
      title = doc.search(@config.name_selector).map(&:text).first || ''
      title = title.gsub("'", "&#39;") if @config.encode_title?
      title
    end
    
    def extract_domain(url)
      URI.parse(url).host
    end
  end
  
  class ScrapedContent
    attr_reader :content, :title, :url, :domain
    
    def initialize(content:, title:, url:, domain:)
      @content = content
      @title = title
      @url = url
      @domain = domain
    end
    
    def process_relative_urls
      return content unless domain
      
      content.gsub("href=\"/", "href=\"https://#{domain}/")
             .gsub("src=\"/", "src=\"https://#{domain}/")
    end
  end
end