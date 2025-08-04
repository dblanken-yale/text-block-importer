# frozen_string_literal: true

require_relative 'text_block_importer/config'
require_relative 'text_block_importer/logger'
require_relative 'text_block_importer/validator'
require_relative 'text_block_importer/path_helper'
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
  
  VERSION = '2.0.0'
end