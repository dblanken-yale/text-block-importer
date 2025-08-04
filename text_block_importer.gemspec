# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'text_block_importer'
  spec.version = '2.0.0'
  spec.summary = 'Extract web content and convert to YaleSite YAML format'
  spec.description = 'A tool for importing web content into YaleSite text blocks through YAML files, ' \
                     'specifically designed for single content sync implementations.'
  
  spec.authors = ['Yale ITS']
  spec.email = ['its-web-dev@yale.edu']
  
  spec.files = Dir['lib/**/*', 'README.md', 'template.yml']
  spec.executables = ['text_block_importer']
  spec.require_paths = ['lib']
  
  spec.required_ruby_version = '>= 3.0.0'
  
  spec.add_dependency 'nokogiri', '~> 1.15'
  
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
end
