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
      
      html_output = doc.css(selector)
      html_output = html_output.map { |output| output.to_s.strip.gsub("\n", "") }.join(" ")
      
      if html_output.empty?
        STDERR.puts("No data found for the given selector.")
        return []
      end
      
      urls = html_output.scan(/href=["'](\/[^"']*)["']|href=["'](https?:\/\/#{domain}[^"']*)["']/).flatten.compact
      
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