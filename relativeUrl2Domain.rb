def override_domain(domain, html_output)
  if domain
    html_output = html_output.gsub("href=\"/", "href=\"https://#{domain}/")
    html_output = html_output.gsub("src=\"/", "src=\"https://#{domain}/")
  end
  html_output
end

if (ARGV.length == 2)
  domain = ARGV[0]
  html_output = ARGV[1]
  puts override_domain(domain, html_output)
else
  puts "Usage: ruby #{ARGV[0]} <domain> <html_output>"
end
