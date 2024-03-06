require 'net/http'
require 'nokogiri'
require 'securerandom'
require 'cgi'

if ARGV.length < 4
  puts "Usage: ruby #{__FILE__} <URI> <html selector> <template file> <output file>"
  exit
end

# Fetch HTML content
uri = URI.parse(ARGV[0])
response = Net::HTTP.get_response(uri)

if response.is_a? Net::HTTPMovedPermanently then
  redirect_uri = URI.parse(response['location'])
  response = Net::HTTP.get_response(redirect_uri)
end

html = response.body
doc = Nokogiri::HTML(html)
html_output = doc.at(ARGV[1])

first_h1 = 
  begin
    doc.search("h1").map(&:text).first
  rescue => e
    ""
  end

html_output = html_output.to_s.strip.gsub("\n", "").gsub("'", "&#39;")
# Extract web page file name from URI
web_page_file_name = File.basename(uri.path) || ""

# Define replacements
replacements = {
  "{NAME}" => first_h1,
  "{URL}" => "/#{web_page_file_name}",
  "{UUID}" => SecureRandom.uuid,
  "{BLOCK_UUID}" => SecureRandom.uuid,
  "{REPLACEME}" => html_output,
}

# Load template content
template_content = File.read(ARGV[2])

# Perform replacements
replacements.each do |placeholder, value|
  if value then
    template_content.gsub!(placeholder, value)
  else
    puts "Could not replace for #{placeholder} in #{ARGV[2]}"
  end
end

# Output to output file
File.open(ARGV[3], "w") do |file|
  file.puts template_content
end
