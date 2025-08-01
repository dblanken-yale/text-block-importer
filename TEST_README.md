# Test Suite Documentation

This document describes the comprehensive test suite for the Text Block Importer tool.

## Overview

The test suite provides thorough coverage of all components in the Text Block Importer, including:

- **Unit Tests**: Test individual classes and methods in isolation
- **Integration Tests**: Test complete workflows and component interactions  
- **Shell Script Tests**: Basic validation of shell script functionality
- **Performance Tests**: Ensure acceptable performance with large datasets

## Test Structure

```
spec/
├── spec_helper.rb              # Main test configuration
├── support/                    # Test support files
│   ├── test_helpers.rb        # Helper methods for tests
│   └── shared_examples.rb     # Shared test examples
├── fixtures/                   # Test data files
│   ├── sample_page.html       # Sample HTML page
│   ├── page_with_quotes.html  # HTML with special characters
│   ├── empty_page.html        # Page with no content
│   ├── sample_sitemap.xml     # Basic sitemap
│   ├── nested_sitemap_index.xml # Sitemap index
│   └── test_template.yml      # Test YAML template
├── lib/                       # Unit tests
│   └── text_block_importer/
│       ├── config_spec.rb
│       ├── http_client_spec.rb
│       ├── scraper_spec.rb
│       ├── sitemap_parser_spec.rb
│       ├── url_extractor_spec.rb
│       └── yaml_generator_spec.rb
└── integration/               # Integration tests
    ├── full_workflow_spec.rb
    └── shell_scripts_spec.rb
```

## Running Tests

### Basic Test Commands

```bash
# Run all tests
bundle exec rspec

# Run all tests with coverage
COVERAGE=true bundle exec rspec

# Run only unit tests
bundle exec rspec spec/lib/

# Run only integration tests  
bundle exec rspec spec/integration/

# Run specific test file
bundle exec rspec spec/lib/text_block_importer/scraper_spec.rb

# Run tests with specific tags
bundle exec rspec --tag focus
```

### Rake Tasks

The test suite includes comprehensive Rake tasks:

```bash
# Basic test tasks
rake spec                    # Run all tests
rake spec:unit              # Run unit tests only
rake spec:integration       # Run integration tests only
rake spec:fast              # Run unit tests with progress format
rake spec:ci                # CI-friendly output with JUnit XML

# Coverage and quality
rake test:coverage          # Run tests with detailed coverage report
rake quality               # Run tests and linting
rake rubocop               # Run RuboCop linter

# Development helpers
rake dev:console           # Open console with library loaded
rake dev:debug             # Run tests in debug mode
rake test:failures         # Run only failing tests

# Statistics and verification
rake stats:loc             # Show lines of code statistics  
rake stats:tests           # Show test statistics
rake verify:env            # Verify test environment setup
```

## Test Configuration

### Environment Variables

- `COVERAGE=true` - Enable coverage reporting
- `CI=true` - Enable CI-specific settings  
- `DEBUG=true` - Enable debug output
- `VERBOSE=true` - Enable verbose test output

### RSpec Configuration

Key RSpec settings in `spec_helper.rb`:

- **Coverage**: SimpleCov with 85% minimum coverage requirement
- **WebMock**: HTTP request stubbing for integration tests
- **Random Order**: Tests run in random order to catch dependencies
- **Shared Examples**: Reusable test patterns for common scenarios
- **Test Helpers**: Utility methods for creating test data

## Unit Tests

### Scraper (`scraper_spec.rb`)

Tests the core content scraping functionality:

- ✅ CSS selector content extraction
- ✅ Title extraction with configurable selectors
- ✅ Content processing (newline stripping, quote encoding)
- ✅ Empty content handling and warnings
- ✅ Error handling for network failures
- ✅ Malformed HTML handling
- ✅ Relative URL processing

**Key Test Scenarios:**
- Valid HTML content extraction
- Content processing options (strip newlines, encode quotes)
- Empty content warnings
- Network error handling
- ScrapedContent object functionality

### YAML Generator (`yaml_generator_spec.rb`)

Tests YAML template processing and file generation:

- ✅ Template token replacement (`{NAME}`, `{URL}`, `{UUID}`, etc.)
- ✅ UUID generation and validation
- ✅ File saving with directory creation
- ✅ Relative URL processing option
- ✅ Error handling for missing templates
- ✅ Permission error handling

**Key Test Scenarios:**
- Complete token replacement
- Valid UUID generation
- File system operations
- Configuration-based processing

### URL Extractor (`url_extractor_spec.rb`)

Tests URL extraction from HTML pages:

- ✅ CSS selector-based URL extraction
- ✅ Relative to absolute URL conversion
- ✅ Same-domain filtering
- ✅ Various href attribute formats
- ✅ Complex selector support
- ✅ Error handling for missing selectors

**Key Test Scenarios:**
- Link extraction from navigation elements
- URL format handling (relative, absolute, special characters)
- Domain filtering logic
- Empty content handling

### Sitemap Parser (`sitemap_parser_spec.rb`)

Tests XML sitemap parsing with recursive support:

- ✅ Single sitemap URL extraction
- ✅ Recursive nested sitemap parsing
- ✅ Paginated sitemap handling
- ✅ Maximum depth limiting
- ✅ Same-domain-only restrictions
- ✅ Circular reference prevention
- ✅ Error handling for malformed XML

**Key Test Scenarios:**
- Basic sitemap parsing
- Nested sitemap index files
- Paginated sitemaps (sitemap.xml?page=1)
- Error recovery for failed nested sitemaps

### HTTP Client (`http_client_spec.rb`)

Tests HTTP request handling:

- ✅ Basic HTTP GET requests
- ✅ Redirect following (301 redirects)
- ✅ Retry logic with configurable attempts
- ✅ Various network error handling
- ✅ Response body processing
- ✅ URL format handling

**Key Test Scenarios:**
- Successful HTTP requests
- Redirect handling
- Network error recovery with retries
- Different response types (empty, large, binary)

### Configuration (`config_spec.rb`)

Tests configuration loading and management:

- ✅ Default configuration loading
- ✅ Custom configuration file support
- ✅ Configuration merging (multiple files)
- ✅ Deep hash merging
- ✅ All configuration options
- ✅ Invalid YAML handling

**Key Test Scenarios:**
- Default configuration values
- Custom configuration override
- Multiple configuration file merging
- Missing file handling

## Integration Tests

### Full Workflow (`full_workflow_spec.rb`)

Tests complete end-to-end workflows:

- ✅ Single page scraping and YAML generation
- ✅ URL extraction workflow
- ✅ Sitemap parsing workflow
- ✅ Batch processing simulation
- ✅ Error handling throughout workflow
- ✅ Configuration integration
- ✅ Performance with large datasets

**Key Test Scenarios:**
- Complete scraping pipeline: HTML → ScrapedContent → YAML → File
- Sitemap parsing → URL extraction → Content scraping
- Error recovery and continuation
- Memory and performance characteristics

### Shell Scripts (`shell_scripts_spec.rb`)

Tests shell script functionality where possible:

- ✅ Executable permissions and structure
- ✅ Argument validation
- ✅ Input file validation
- ✅ Error message quality
- ✅ Security vulnerability checks
- ✅ Dependency verification

**Key Test Scenarios:**
- Script execution with various arguments
- File validation logic
- Error handling and user feedback
- Security best practices

## Test Data and Fixtures

### HTML Fixtures

- **`sample_page.html`**: Complete HTML page with various content types
- **`page_with_quotes.html`**: HTML containing single/double quotes and special characters
- **`empty_page.html`**: HTML page with empty content areas

### XML Fixtures

- **`sample_sitemap.xml`**: Standard sitemap with multiple URLs
- **`nested_sitemap_index.xml`**: Sitemap index pointing to nested sitemaps

### Template Fixtures

- **`test_template.yml`**: Simplified YAML template for testing token replacement

## Shared Examples and Helpers

### Shared Examples (`shared_examples.rb`)

Reusable test patterns for common scenarios:

- **HTTP Operations**: Network error handling and retry logic
- **Content Processing**: Empty content and configuration handling
- **YAML Generation**: Template processing and structure validation
- **URL Processing**: Relative/absolute URL handling
- **Error Handling**: Consistent error message and type validation
- **File Operations**: Directory creation and permission handling

### Test Helpers (`test_helpers.rb`)

Utility methods for test setup:

- **`mock_config(overrides)`**: Create mock configuration objects
- **`stub_http_request(url, body)`**: Stub HTTP requests for testing
- **`sample_html_with_content(title, content)`**: Generate test HTML
- **`sample_sitemap_xml(urls)`**: Generate test sitemaps
- **`expect_yaml_structure(yaml, keys)`**: Validate YAML structure
- **`expect_valid_uuid(uuid)`**: Validate UUID format

## Coverage Requirements

The test suite maintains high coverage standards:

- **Minimum Coverage**: 85% overall
- **Coverage Groups**: Organized by functionality (Core, Processing, Parsing, etc.)
- **Coverage Reports**: HTML and console output available
- **CI Integration**: Coverage uploaded to Codecov in CI

### Running Coverage Reports

```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View HTML coverage report
open coverage/index.html

# CI coverage with multiple formats
bundle exec rake spec:ci
```

## Continuous Integration

### GitHub Actions

The CI pipeline (`.github/workflows/test.yml`) includes:

- **Multi-Ruby Testing**: Ruby 3.0, 3.1, 3.2, 3.3
- **Linting**: RuboCop for code style
- **Shell Script Linting**: ShellCheck for bash scripts
- **Security Scanning**: Bundler audit for vulnerability detection
- **Performance Testing**: Large dataset performance validation
- **Coverage Reporting**: Codecov integration

### CI Commands

```bash
# Run full CI test suite locally
bundle exec rake spec:ci

# Run linting
bundle exec rubocop

# Verify dependencies
bundle exec rake verify:deps
```

## Development Workflow

### Adding New Tests

1. **Unit Tests**: Add to `spec/lib/text_block_importer/`
2. **Integration Tests**: Add to `spec/integration/`
3. **Fixtures**: Add test data to `spec/fixtures/`
4. **Shared Examples**: Add reusable patterns to `shared_examples.rb`

### Test-Driven Development

```bash
# Run tests in watch mode (requires guard or similar)
bundle exec rake test:watch

# Run only failing tests
bundle exec rake test:failures

# Debug specific test
DEBUG=true bundle exec rspec spec/path/to/spec.rb:line_number
```

### Test Quality Guidelines

- **Descriptive Names**: Test names should clearly describe the scenario
- **AAA Pattern**: Arrange, Act, Assert structure
- **Isolation**: Each test should be independent
- **Coverage**: Aim for both happy path and edge cases
- **Performance**: Consider test execution time
- **Maintainability**: Use shared examples and helpers appropriately

## Troubleshooting

### Common Issues

**Tests failing with network errors:**
```bash
# Ensure WebMock is properly configured
# Check that HTTP requests in tests are stubbed
```

**Coverage not generating:**
```bash
# Run with coverage enabled
COVERAGE=true bundle exec rspec
```

**Fixtures not loading:**
```bash
# Verify fixture files exist in spec/fixtures/
# Check file permissions are readable
```

**Shell script tests skipping:**
```bash
# Ensure shell scripts have execute permissions
chmod +x makeYamls.sh retrieveSitemap
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
DEBUG=true bundle exec rspec
```

This provides additional logging and preserves temporary files for inspection.

## Performance Testing

The test suite includes performance considerations:

- **Large Dataset Tests**: Verify handling of 100+ URL sitemaps
- **Memory Usage**: Monitor memory consumption during batch processing
- **Execution Time**: Ensure reasonable performance for typical use cases

Performance tests are tagged and can be run separately:

```bash
bundle exec rspec --tag performance
```

## Contributing to Tests

When contributing new features:

1. **Add Unit Tests**: Cover all new methods and classes
2. **Add Integration Tests**: Cover new workflows
3. **Update Fixtures**: Add new test data as needed
4. **Maintain Coverage**: Ensure coverage remains above 85%
5. **Update Documentation**: Keep this README current

The test suite is designed to provide confidence in the reliability and correctness of the Text Block Importer tool while maintaining fast execution times and clear failure diagnostics.