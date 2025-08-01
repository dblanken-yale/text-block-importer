# frozen_string_literal: true

require 'net/http'
require 'uri'

module TextBlockImporter
  class HttpClient
    def initialize(config = Config.new, logger = nil)
      @config = config
      @logger = logger
    end
    
    def fetch(url)
      uri = URI.parse(url)
      retries = 0
      
      @logger&.debug("Fetching URL: #{url}")
      
      begin
        response = Net::HTTP.get_response(uri)
        response = handle_redirects(response) if @config.follow_redirects?
        
        @logger&.debug("Response status: #{response.code}")
        response.body
      rescue => e
        retries += 1
        @logger&.warn("Fetch attempt #{retries} failed: #{e.message}")
        
        if retries <= @config.retries
          @logger&.info("Retrying... (#{retries}/#{@config.retries})")
          retry
        end
        
        raise NetworkError, "Failed to fetch #{url} after #{@config.retries} retries: #{e.message}"
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