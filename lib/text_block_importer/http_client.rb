require 'net/http'
require 'uri'

module TextBlockImporter
  class HttpClient
    def initialize(config = Config.new)
      @config = config
    end
    
    def fetch(url)
      uri = URI.parse(url)
      retries = 0
      
      begin
        response = Net::HTTP.get_response(uri)
        response = handle_redirects(response) if @config.follow_redirects
        response.body
      rescue => e
        retries += 1
        retry if retries <= @config.retries
        raise NetworkError, "Failed to fetch #{url}: #{e.message}"
      end
    end
    
    private
    
    def handle_redirects(response)
      if response.is_a?(Net::HTTPMovedPermanently)
        redirect_uri = URI.parse(response['location'])
        Net::HTTP.get_response(redirect_uri)
      else
        response
      end
    end
  end
end