module TextBlockImporter
  class Config
    DEFAULT_USER_AGENT = 'TextBlockImporter/1.0'
    DEFAULT_TIMEOUT = 30
    DEFAULT_RETRIES = 3
    
    attr_accessor :user_agent, :timeout, :retries, :follow_redirects
    
    def initialize
      @user_agent = DEFAULT_USER_AGENT
      @timeout = DEFAULT_TIMEOUT
      @retries = DEFAULT_RETRIES
      @follow_redirects = true
    end
  end
end