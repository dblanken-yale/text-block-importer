# Development Guide

## Architecture Overview

Text Block Importer follows a modular Ruby architecture with clear separation of concerns:

```
lib/text_block_importer/
├── cli.rb              # Command-line interface and argument parsing
├── config.rb           # Configuration management with YAML support
├── logger.rb           # Structured logging with contextual information
├── validator.rb        # Input validation and error prevention
├── http_client.rb      # HTTP requests with retry logic and redirects
├── scraper.rb          # Web scraping using Nokogiri
├── yaml_generator.rb   # YAML file generation from templates
├── url_extractor.rb    # URL extraction from web pages
└── sitemap_parser.rb   # XML sitemap parsing
```

## Configuration System

The application uses a hierarchical configuration system:

1. **Default config** (`config/default.yml`) - Base configuration
2. **User config** (`~/.text_block_importer.yml`) - User-specific settings
3. **Project config** (`./text_block_importer.yml`) - Project-specific settings
4. **CLI arguments** - Runtime overrides

Configuration files are merged with later files taking precedence.

## Logging

The logging system provides structured, contextual logging:

```ruby
logger = CustomLogger.new(level: :info)
contextual_logger = logger.with_context('Scraper')
contextual_logger.info("Processing URL: #{url}")
# Output: [2024-01-01 12:00:00] INFO: [Scraper] Processing URL: https://example.com
```

## Error Handling

Custom exception hierarchy for specific error types:

- `TextBlockImporter::Error` - Base error class
- `TextBlockImporter::NetworkError` - HTTP/network related errors
- `TextBlockImporter::SelectorError` - CSS selector or content extraction errors
- `TextBlockImporter::ValidationError` - Input validation errors

## Input Validation

The `Validator` class provides comprehensive input validation:

- URL format and accessibility validation
- CSS selector syntax validation
- File existence and permission checks
- Template file content validation

## Development Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Run linting:
   ```bash
   bundle exec rubocop
   ```

3. Run tests (when implemented):
   ```bash
   bundle exec rspec
   ```

## Adding New Features

### Adding a New Command

1. Add the command to `CLI#run` method
2. Implement the command method following existing patterns
3. Add input validation using `Validator` class
4. Add logging using contextual loggers
5. Update help text in `CLI#show_help`

### Adding Configuration Options

1. Add default values to `config/default.yml`
2. Add accessor methods to `Config` class
3. Update relevant classes to use the new configuration
4. Document the option in examples

### Error Handling Best Practices

- Use specific exception types
- Provide actionable error messages
- Log errors with appropriate context
- Allow graceful degradation where possible

## Testing Strategy

Future testing should include:

- Unit tests for each class
- Integration tests for CLI commands
- Mock HTTP responses for reliable testing
- Configuration loading tests
- Validation logic tests

## Code Style

The project follows Ruby community standards:

- Use RuboCop for linting
- Frozen string literals at the top of each file
- Descriptive method and variable names
- Comprehensive documentation for public APIs

## Performance Considerations

- HTTP client includes retry logic and timeout handling
- Batch processing includes progress feedback
- Memory-efficient file processing for large batches
- Configurable concurrency limits (future enhancement)