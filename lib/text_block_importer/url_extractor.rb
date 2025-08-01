require 'uri'

module TextBlockImporter
  class UrlExtractor
    def initialize(http_client = HttpClient.new)
      @http_client = http_client
    end
    
    def extract(url, selector)
      html = @http_client.fetch(url)
      doc = Nokogiri::HTML(html)
      
      uri = URI.parse(url)
      domain = uri.host
      
      links = doc.css(selector)
      
      if links.empty?
        STDERR.puts("No data found for the given selector.")
        return []
      end
      
      urls = links.map { |link| link['href'] }.compact.select { |href| 
        href.start_with?('/') || href.start_with?("http://#{domain}") || href.start_with?("https://#{domain}")
      }
      
      urls.map do |extracted_url|
        if extracted_url.start_with?("/")
          "#{uri.scheme}://#{domain}#{extracted_url}"
        else
          extracted_url
        end
      end
    end
  end
end