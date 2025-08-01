require 'net/http'
require 'uri'

module TextBlockImporter
  class SitemapParser
    def initialize(http_client = HttpClient.new)
      @http_client = http_client
    end
    
    def parse(sitemap_url)
      xml_content = @http_client.fetch(sitemap_url)
      
      urls = []
      xml_content.scan(/<loc>(.*?)<\/loc>/) do |match|
        urls << match[0]
      end
      
      if urls.empty?
        STDERR.puts("Could not retrieve sitemap.xml")
        exit 1
      end
      
      urls
    rescue => e
      STDERR.puts("Error parsing sitemap: #{e.message}")
      exit 1
    end
  end
end