#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Basic usage of Text Block Importer classes

require_relative '../lib/text_block_importer'

# Initialize with default configuration
config = TextBlockImporter::Config.new
logger = TextBlockImporter::CustomLogger.new(level: :info)

puts "=== Text Block Importer Example ==="

# Example 1: Scrape a single page
begin
  scraper = TextBlockImporter::Scraper.new(config, logger.with_context('Example'))
  content = scraper.scrape('https://httpbin.org/html', 'body')
  
  puts "Title: #{content.title}"
  puts "Content length: #{content.content.length} characters"
  puts "Domain: #{content.domain}"
rescue TextBlockImporter::Error => e
  puts "Error: #{e.message}"
end

# Example 2: Generate YAML from scraped content
begin
  generator = TextBlockImporter::YamlGenerator.new(
    '../template.yml',
    config,
    logger.with_context('Generator')
  )
  
  # This would normally use scraped content
  # yaml = generator.generate(content, use_domains: true)
  # puts "Generated YAML length: #{yaml.length} characters"
rescue TextBlockImporter::Error => e
  puts "Error: #{e.message}"
end

puts "=== Example Complete ==="