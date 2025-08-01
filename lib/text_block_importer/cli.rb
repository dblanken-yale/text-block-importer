# frozen_string_literal: true

module TextBlockImporter
  class CLI
    def self.run(args)
      new(args).run
    end
    
    def initialize(args)
      @args = args
      @options = parse_options
      @config = Config.new(config_path: @options[:config])
      @logger = CustomLogger.new(
        level: @config.log_level,
        output: @config.log_output
      )
    end
    
    def run
      # Handle version and help flags first
      if @args.include?('--version') || @args.include?('-v')
        show_version
        return
      end
      
      if @args.include?('--help') || @args.include?('-h')
        show_help
        return
      end
      
      case @args[0]
      when 'scrape'
        scrape_single
      when 'batch'
        batch_process
      when 'extract-urls'
        extract_urls
      when 'sitemap'
        process_sitemap
      else
        show_help
        exit 1
      end
    rescue TextBlockImporter::Error => e
      STDERR.puts "Error: #{e.message}"
      exit 1
    end
    
    private
    
    def scrape_single
      url, selector, template, output = @args[1..4]
      validate_args!([url, selector, template, output], "scrape <url> <selector> <template> <output>")
      
      # Input validation
      Validator.validate_url!(url)
      Validator.validate_css_selector!(selector)
      Validator.validate_template_file!(template)
      Validator.validate_output_directory!(output)
      
      @logger.info("Starting single page scrape: #{url}")
      
      scraper = Scraper.new(@config, @logger.with_context('Scraper'))
      generator = YamlGenerator.new(template, @config, @logger.with_context('Generator'))
      
      content = scraper.scrape(url, selector)
      yaml = generator.generate(content, @options)
      generator.save(yaml, output)
      
      @logger.info("Generated: #{output}")
      puts "Generated: #{output}"
    end
    
    def batch_process
      url_file, selector, template = @args[1..3]
      validate_args!([url_file, selector, template], "batch <url_file> <selector> <template>")
      
      # Input validation
      Validator.validate_file_exists!(url_file, 'URL file')
      Validator.validate_css_selector!(selector)
      Validator.validate_template_file!(template)
      
      @logger.info("Starting batch processing from: #{url_file}")
      
      scraper = Scraper.new(@config, @logger.with_context('Scraper'))
      generator = YamlGenerator.new(template, @config, @logger.with_context('Generator'))
      
      urls = File.readlines(url_file, chomp: true).map(&:strip).reject(&:empty?)
      
      if urls.empty?
        @logger.warn("No URLs found in file: #{url_file}")
        puts "No URLs found in file: #{url_file}"
        return
      end
      
      # Use first URL to determine domain for output directory
      base_url = urls.first
      path_helper = PathHelper.new(@config, @logger.with_context('PathHelper'))
      
      processed = 0
      failed = 0
      
      urls.each_with_index do |url, index|
        output_file = path_helper.build_batch_output_path(base_url, index + 1)
        
        if @config.show_progress?
          progress = "#{index + 1}/#{urls.length}"
          puts "[#{progress}] Processing: #{url}"
        end
        
        begin
          Validator.validate_url!(url)
          content = scraper.scrape(url, selector)
          yaml = generator.generate(content, @options)
          generator.save(yaml, output_file)
          
          @logger.info("Generated: #{output_file}")
          processed += 1
        rescue => e
          @logger.error("Failed to process #{url}: #{e.message}")
          failed += 1
          
          unless @config.continue_on_error?
            @logger.fatal("Stopping batch processing due to error")
            exit 1
          end
        end
      end
      
      @logger.info("Batch processing complete: #{processed} successful, #{failed} failed")
      puts "Batch processing complete: #{processed} successful, #{failed} failed"
    end
    
    def extract_urls
      url, selector = @args[1..2]
      validate_args!([url, selector], "extract-urls <url> <selector>")
      
      require_relative 'url_extractor'
      extractor = UrlExtractor.new
      urls = extractor.extract(url, selector)
      puts urls.join("\n")
    end
    
    def process_sitemap
      sitemap_url = @args[1]
      validate_args!([sitemap_url], "sitemap <sitemap_url> [--output filename]")
      
      # Input validation
      Validator.validate_url!(sitemap_url)
      
      @logger.info("Processing sitemap: #{sitemap_url}")
      
      parser = SitemapParser.new(@config, @logger.with_context('SitemapParser'))
      urls = parser.parse(sitemap_url)
      
      # Use PathHelper to determine output location
      path_helper = PathHelper.new(@config, @logger.with_context('PathHelper'))
      output_file = path_helper.build_sitemap_output_path(sitemap_url, @options[:output])
      
      File.write(output_file, urls.join("\n"))
      
      @logger.info("Retrieved #{urls.length} URLs to #{output_file}")
      puts "Retrieved #{urls.length} URLs to #{output_file}"
      
      if @config.sitemap_recursive?
        puts "Note: Recursive sitemap parsing was enabled - nested sitemaps were processed automatically"
      end
    end
    
    def show_help
      puts <<~HELP
        Text Block Importer - Extract web content and convert to YAML
        
        Usage:
          text_block_importer scrape <url> <selector> <template> <output> [--use-domains]
          text_block_importer batch <url_file> <selector> <template> [--use-domains]
          text_block_importer extract-urls <url> <selector>
          text_block_importer sitemap <sitemap_url> [--output filename]
        
        Commands:
          scrape        Convert single web page to YAML
          batch         Process multiple URLs from file
          extract-urls  Extract URLs from page using CSS selector
          sitemap       Extract URLs from XML sitemap (supports nested/paginated sitemaps)
        
        Options:
          --use-domains     Replace relative URLs with source domain
          --output filename Specify output file for sitemap command (default: sitemap.links)
          --config path     Use custom configuration file
          --verbose, -v     Enable verbose logging
        
        Examples:
          # Extract single page
          text_block_importer scrape https://example.com '.content' template.yml output.yml
          
          # Process multiple URLs from file
          text_block_importer batch my-urls.txt '.main-content' template.yml --use-domains
          
          # Extract sitemap with custom output filename
          text_block_importer sitemap https://example.com/sitemap.xml --output my-sitemap-urls.txt
          
          # Use custom sitemap output in batch processing
          text_block_importer batch my-sitemap-urls.txt '.content' template.yml
          
          # Extract URLs from page
          text_block_importer extract-urls https://example.com 'a'
      HELP
    end
    
    def show_version
      puts "#{TextBlockImporter::VERSION}"
    end
    
    def parse_options
      options = {}
      options[:use_domains] = @args.include?('--use-domains')
      @args.delete('--use-domains')
      
      # Extract config file option
      config_index = @args.find_index('--config')
      if config_index && @args[config_index + 1]
        options[:config] = @args[config_index + 1]
        @args.slice!(config_index, 2)
      end
      
      # Extract output file option
      output_index = @args.find_index('--output')
      if output_index && @args[output_index + 1]
        options[:output] = @args[output_index + 1]
        @args.slice!(output_index, 2)
      end
      
      # Extract verbose option
      options[:verbose] = @args.include?('--verbose') || @args.include?('-v')
      @args.delete('--verbose')
      @args.delete('-v')
      
      options
    end
    
    def validate_args!(args, usage)
      if args.any?(&:nil?)
        STDERR.puts "Error: Missing required arguments"
        STDERR.puts "Usage: text_block_importer #{usage}"
        exit 1
      end
    end
  end
end