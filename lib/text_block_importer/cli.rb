module TextBlockImporter
  class CLI
    def self.run(args)
      new(args).run
    end
    
    def initialize(args)
      @args = args
      @options = parse_options
    end
    
    def run
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
      end
    rescue TextBlockImporter::Error => e
      STDERR.puts "Error: #{e.message}"
      exit 1
    end
    
    private
    
    def scrape_single
      url, selector, template, output = @args[1..4]
      validate_args!([url, selector, template, output], "scrape <url> <selector> <template> <output>")
      
      scraper = Scraper.new
      generator = YamlGenerator.new(template)
      
      content = scraper.scrape(url, selector)
      yaml = generator.generate(content, @options)
      generator.save(yaml, output)
      
      puts "Generated: #{output}"
    end
    
    def batch_process
      url_file, selector, template = @args[1..3]
      validate_args!([url_file, selector, template], "batch <url_file> <selector> <template>")
      
      unless File.exist?(url_file)
        STDERR.puts "Error: URL file #{url_file} not found"
        exit 1
      end
      
      scraper = Scraper.new
      generator = YamlGenerator.new(template)
      
      File.readlines(url_file, chomp: true).each_with_index do |url, index|
        next if url.strip.empty?
        
        output_file = "node-#{index + 1}.output.yml"
        puts "Creating yaml for #{url}"
        
        begin
          content = scraper.scrape(url.strip, selector)
          yaml = generator.generate(content, @options)
          generator.save(yaml, output_file)
        rescue => e
          STDERR.puts "Failed to process #{url}: #{e.message}"
        end
      end
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
      validate_args!([sitemap_url], "sitemap <sitemap_url>")
      
      require_relative 'sitemap_parser'
      parser = SitemapParser.new
      urls = parser.parse(sitemap_url)
      
      File.write('sitemap.links', urls.join("\n"))
      puts "Retrieved sitemap.links"
    end
    
    def show_help
      puts <<~HELP
        Text Block Importer - Extract web content and convert to YAML
        
        Usage:
          text_block_importer scrape <url> <selector> <template> <output> [--use-domains]
          text_block_importer batch <url_file> <selector> <template> [--use-domains]
          text_block_importer extract-urls <url> <selector>
          text_block_importer sitemap <sitemap_url>
        
        Commands:
          scrape        Convert single web page to YAML
          batch         Process multiple URLs from file
          extract-urls  Extract URLs from page using CSS selector
          sitemap       Extract URLs from XML sitemap
        
        Options:
          --use-domains Replace relative URLs with source domain
        
        Examples:
          text_block_importer scrape https://example.com '.content' template.yml output.yml
          text_block_importer batch urls.txt '.main-content' template.yml --use-domains
          text_block_importer extract-urls https://example.com 'a'
          text_block_importer sitemap https://example.com/sitemap.xml
      HELP
    end
    
    def parse_options
      options = {}
      options[:use_domains] = @args.include?('--use-domains')
      @args.delete('--use-domains')
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