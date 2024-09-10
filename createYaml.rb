require 'net/http'
require 'nokogiri'
require 'securerandom'
require 'cgi'

def override_domain(domain, html_output)
  if domain
    html_output = html_output.gsub("href=\"/", "href=\"https://#{domain}/")
    html_output = html_output.gsub("src=\"/", "src=\"https://#{domain}/")
  end
  html_output
end

if ARGV.length < 4
  puts "Usage: ruby #{__FILE__} <URI> <html selector> <template file> <output file> --use-domains"
  puts ""
  puts "--use-domains: optional flag to replace relative URLs with domain of source"

  exit
end

use_domains = false

# Set to replace relative URLs with domain of source if --use-domains is set in ARGV
if ARGV.include?("--use-domains")
  ARGV.delete("--use-domains")
  use_domains = true
end

# Fetch HTML content
uri = URI.parse(ARGV[0])
response = Net::HTTP.get_response(uri)
domain = ARGV[0].split("/")[2]

# For permanent redirects, follow the redirect
if response.is_a? Net::HTTPMovedPermanently then
  redirect_uri = URI.parse(response['location'])
  response = Net::HTTP.get_response(redirect_uri)
end

html = response.body
doc = Nokogiri::HTML(html)
html_output = doc.at(ARGV[1])

# Attempt to find a h1 in the content to set as the title.  Make sure to encode
# similarly to we will the html output.
first_h1 = 
  begin
    doc.search("h1").map(&:text).first
  rescue => e
    ""
  end.gsub("'", "&#39;")

# So far only single quotes made us not work, so I'm encoding them.
html_output = html_output.to_s.strip.gsub("\n", "").gsub("'", "&#39;")

# if use domains was set, replace all relative URLs with original domains.
html_output = override_domain(domain, html_output) if use_domains

if (html_output.empty?)
  STDERR.puts("No data found for the given selector...continuing--be aware! [#{ARGV[0]}]")
end

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
