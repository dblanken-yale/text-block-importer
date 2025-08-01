require_relative 'text_block_importer/config'
require_relative 'text_block_importer/http_client'
require_relative 'text_block_importer/scraper'
require_relative 'text_block_importer/yaml_generator'
require_relative 'text_block_importer/url_extractor'
require_relative 'text_block_importer/sitemap_parser'
require_relative 'text_block_importer/cli'

module TextBlockImporter
  class Error < StandardError; end
  class NetworkError < Error; end
  class SelectorError < Error; end
end