require 'nokogiri'
require 'uri'

module TextBlockImporter
  class Scraper
    def initialize(http_client = HttpClient.new)
      @http_client = http_client
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
      
      content = element.to_s.strip.gsub("\n", "").gsub("'", "&#39;")
      if content.empty?
        STDERR.puts("No data found for the given selector...continuing--be aware! [#{selector}]")
        return ''
      end
      content
    end
    
    def extract_title(doc)
      doc.search("h1").map(&:text).first&.gsub("'", "&#39;") || ''
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