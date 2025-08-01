#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Testing nested sitemap detection logic

require_relative '../lib/text_block_importer'

config = TextBlockImporter::Config.new
logger = TextBlockImporter::CustomLogger.new(level: :debug)
parser = TextBlockImporter::SitemapParser.new(config, logger)

puts "=== Nested Sitemap Detection Examples ==="

# Test cases for nested sitemap detection
test_cases = [
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://example.com/sitemap-posts.xml',
    expected: true,
    reason: 'Same domain, same directory, sitemap pattern'
  },
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://example.com/sitemap-pages.xml',
    expected: true,
    reason: 'Same domain, same directory, sitemap pattern'
  },
  {
    parent: 'https://example.com/sitemaps/sitemap.xml',
    url: 'https://example.com/sitemaps/sitemap-news.xml',
    expected: true,
    reason: 'Same domain, same subdirectory, sitemap pattern'
  },
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://other.com/sitemap.xml',
    expected: false,
    reason: 'Different domain'
  },
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://example.com/blog/page1.html',
    expected: false,
    reason: 'Not a sitemap file'
  },
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://example.com/other/sitemap.xml',
    expected: false,
    reason: 'Different directory path'
  },
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://example.com/sitemap.xml?page=1',
    expected: true,
    reason: 'Paginated sitemap (same path with page parameter)'
  },
  {
    parent: 'https://example.com/sitemap.xml',
    url: 'https://example.com/sitemap.xml?page=2',
    expected: true,
    reason: 'Paginated sitemap (same path with page parameter)'
  }
]

test_cases.each_with_index do |test_case, index|
  result = parser.send(:looks_like_nested_sitemap?, test_case[:url], test_case[:parent])
  status = result == test_case[:expected] ? '✅ PASS' : '❌ FAIL'
  
  puts "#{index + 1}. #{status}"
  puts "   Parent: #{test_case[:parent]}"
  puts "   URL: #{test_case[:url]}"
  puts "   Expected: #{test_case[:expected]}, Got: #{result}"
  puts "   Reason: #{test_case[:reason]}"
  puts
end

puts "=== Example Complete ==="