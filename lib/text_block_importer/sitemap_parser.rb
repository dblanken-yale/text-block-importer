# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'set'

module TextBlockImporter
  class SitemapParser
    def initialize(config = Config.new, logger = nil)
      @config = config
      @logger = logger
      @http_client = HttpClient.new(config, logger)
      @processed_sitemaps = Set.new
    end
    
    def parse(sitemap_url)
      @logger&.info("Starting sitemap parsing: #{sitemap_url}")
      
      all_urls = []
      if @config.sitemap_recursive?
        all_urls = parse_recursive(sitemap_url, depth: 0)
      else
        all_urls = parse_single(sitemap_url)
      end
      
      if all_urls.empty?
        error_msg = "No URLs found in sitemap: #{sitemap_url}"
        @logger&.error(error_msg)
        raise SelectorError, error_msg
      end
      
      @logger&.info("Found #{all_urls.length} total URLs from sitemap(s)")
      all_urls.uniq
    rescue => e
      @logger&.error("Error parsing sitemap: #{e.message}")
      raise SelectorError, "Error parsing sitemap: #{e.message}"
    end
    
    private
    
    def parse_recursive(sitemap_url, depth: 0)
      return [] if depth > @config.sitemap_max_depth
      return [] if @processed_sitemaps.include?(sitemap_url)
      
      @processed_sitemaps << sitemap_url
      @logger&.debug("Parsing sitemap at depth #{depth}: #{sitemap_url}")
      
      xml_content = @http_client.fetch(sitemap_url)
      urls = extract_urls_from_xml(xml_content)
      
      page_urls = []
      nested_sitemap_urls = []
      
      # Separate page URLs from potential nested sitemaps
      urls.each do |url|
        if looks_like_nested_sitemap?(url, sitemap_url)
          nested_sitemap_urls << url
          @logger&.debug("Detected nested sitemap: #{url}")
        else
          page_urls << url
        end
      end
      
      @logger&.info("Found #{page_urls.length} page URLs and #{nested_sitemap_urls.length} nested sitemaps at depth #{depth}")
      
      # Recursively process nested sitemaps
      nested_sitemap_urls.each do |nested_url|
        next if should_skip_sitemap?(nested_url, sitemap_url)
        
        begin
          nested_urls = parse_recursive(nested_url, depth: depth + 1)
          page_urls.concat(nested_urls)
        rescue => e
          @logger&.warn("Failed to parse nested sitemap #{nested_url}: #{e.message}")
        end
      end
      
      page_urls
    end
    
    def parse_single(sitemap_url)
      @logger&.debug("Parsing single sitemap: #{sitemap_url}")
      xml_content = @http_client.fetch(sitemap_url)
      extract_urls_from_xml(xml_content)
    end
    
    def extract_urls_from_xml(xml_content)
      urls = []
      xml_content.scan(/<loc>(.*?)<\/loc>/) do |match|
        urls << match[0].strip
      end
      urls
    end
    
    def looks_like_nested_sitemap?(url, parent_sitemap_url)
      return false unless url.include?('sitemap')
      return false unless url.include?('.xml')  # Changed from end_with to include for query params
      
      # Check if it's from the same domain/path structure
      parent_uri = URI.parse(parent_sitemap_url)
      url_uri = URI.parse(url)
      
      # For cross-domain sitemaps, let should_skip_sitemap? handle the filtering
      # Only return true if it looks like a sitemap (has sitemap and .xml in the URL)
      if parent_uri.host != url_uri.host
        return true  # Let should_skip_sitemap? decide if we should skip this
      end
      
      # For paginated sitemaps like sitemap.xml?page=1
      if url_uri.path == parent_uri.path && url_uri.query&.include?('page')
        @logger&.debug("Detected paginated sitemap: #{url}")
        return true
      end
      
      # Check if the base path is similar (before any query parameters)
      parent_base = "#{parent_uri.scheme}://#{parent_uri.host}#{File.dirname(parent_uri.path)}"
      url_base = "#{url_uri.scheme}://#{url_uri.host}#{File.dirname(url_uri.path)}"
      
      # If the base paths match, it's likely a nested sitemap
      parent_base == url_base
    rescue URI::InvalidURIError
      false
    end
    
    def should_skip_sitemap?(nested_url, parent_url)
      if @config.sitemap_same_domain_only?
        parent_domain = URI.parse(parent_url).host
        nested_domain = URI.parse(nested_url).host
        
        if parent_domain != nested_domain
          @logger&.debug("Skipping cross-domain sitemap: #{nested_url}")
          return true
        end
      end
      
      false
    rescue URI::InvalidURIError
      @logger&.warn("Invalid URL format, skipping: #{nested_url}")
      true
    end
  end
end