require 'net/http'
require 'nokogiri'

if ARGV.length < 2
  puts "Usage: ruby script.rb <URI> <html selector>"
  puts "Example: ruby #{__FILE__} https://your.yale.edu/university-policies-procedures-forms-and-guides body"
  exit
end

uri = URI(ARGV[0])
response = Net::HTTP.get(uri)
doc = Nokogiri::HTML(response)
html_output = doc.css(ARGV[1])
domain = ARGV[2]

# Remove all new lines and extra spaces from the html output for each node found and join them
html_output = html_output.map { |output| output.to_s.strip.gsub("\n", "") }.join(" ")

if (html_output.empty?)
  STDERR.puts("No data found for the given selector.")
  exit
end

# Extract web page file name from URI
web_page_file_name = File.basename(uri.path) || ""
# Extract domain of the URI
domain ||= uri.host

# Get all link urls from the html output where it is from the same domain or is a relative url.
urls = html_output.scan(/href=["'](\/[^"']*)["']|href=["'](https?:\/\/#{domain}[^"']*)["']/).flatten.compact

# For urls starting with /, prepend the domain.
urls.map! do |url|
  if url.start_with?("/")
    uri.scheme + "://" + domain + url
  else
    url
  end
end

puts urls.join("\n")
