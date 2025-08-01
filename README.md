# Text Block Importer

A tool for importing web content into YaleSite text blocks through YAML files, specifically designed for single content sync implementations.

## Overview

Text Block Importer is a Ruby-based tool that helps you:

1. Extract content from websites using CSS selectors
2. Convert the extracted content into YAML files formatted for YaleSite text blocks
3. Process content in bulk from sitemaps or lists of URLs

This tool is especially useful when migrating content from other websites into a YaleSite implementation that uses single content sync.

## Installation

### Prerequisites

- Ruby (recent version)
- [Nokogiri](https://nokogiri.org/) gem
- [libxml2](https://formulae.brew.sh/formula/libxml2) (for sitemap functionality)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/dblanken-yale/text-block-importer.git
   cd text-block-importer
   ```

2. Install required Ruby gems:
   ```bash
   gem install nokogiri
   ```

3. Make the main script executable:
   ```bash
   chmod +x text_block_importer
   ```

## Usage

The tool provides a unified command-line interface with several subcommands:

### 1. Creating a Single YAML File

To create a YAML file for a single page:

```bash
./text_block_importer scrape <URL> <CSS selector> <template file> <output file> [--use-domains]
```

Example:
```bash
./text_block_importer scrape https://example.yale.edu/page.html "main .content" template.yml output.yml
```

Options:
- `--use-domains`: Replace relative URLs with the full domain path from the source website

### 2. Processing Multiple URLs (Batch)

To process multiple URLs and create YAML files for each:

```bash
./text_block_importer batch <url_file> <CSS selector> <template file> [--use-domains]
```

Example:
```bash
./text_block_importer batch urls.txt ".main-content" template.yml --use-domains
```

This will generate numbered YAML files (node-1.output.yml, node-2.output.yml, etc.) for each URL in the input file.

### 3. Extracting URLs from a Page

To extract URLs from a page using a CSS selector:

```bash
./text_block_importer extract-urls <URL> <CSS selector>
```

Example:
```bash
./text_block_importer extract-urls https://example.yale.edu/policies .content-main
```

This will output a list of URLs that can be saved to a file for further processing.

### 4. Processing a Sitemap

To extract URLs from a sitemap:

```bash
./text_block_importer sitemap <sitemap URL>
```

Example:
```bash
./text_block_importer sitemap https://example.yale.edu/sitemap.xml
```

This will create a `sitemap.links` file containing all URLs from the sitemap, which can then be used with the batch command.

### Getting Help

To see all available commands and options:

```bash
./text_block_importer --help
```

## Template Replacements

The following placeholders in your template file will be replaced:

| Placeholder | Replacement |
|-------------|-------------|
| `{NAME}` | The first H1 text found on the page |
| `{URL}` | Path derived from the source URL |
| `{UUID}` | A unique UUID for the node |
| `{BLOCK_UUID}` | A unique UUID for the text block |
| `{REPLACEME}` | The HTML content extracted from the CSS selector |
| `{SOURCE_URL}` | The original source URL |

## Example Workflow

A complete workflow might look like:

1. Extract URLs from a sitemap:
   ```bash
   ./text_block_importer sitemap https://example.yale.edu/sitemap.xml
   ```

2. Process all URLs from the sitemap:
   ```bash
   ./text_block_importer batch sitemap.links ".content-main" template.yml
   ```

3. Import the resulting YAML files into your YaleSite instance using the single content sync process.

## Troubleshooting

If you encounter issues:

- No content extracted: Check if your CSS selector is correct. The tool will show warnings when no content is found.
- XML parsing errors: Make sure you have libxml2 installed for sitemap processing.
- Script execution errors: Ensure the main script has execute permissions (`chmod +x text_block_importer`).

## Migration from Legacy Scripts

If you were using the original Ruby/shell scripts, here's how to migrate to the new unified CLI:

| Legacy Command | New Command |
|----------------|-------------|
| `ruby createYaml.rb <url> <selector> <template> <output> [--use-domains]` | `./text_block_importer scrape <url> <selector> <template> <output> [--use-domains]` |
| `./makeYamls.sh <url_file> <selector> <template> [--use-domains]` | `./text_block_importer batch <url_file> <selector> <template> [--use-domains]` |
| `ruby extractUrls.rb <url> <selector>` | `./text_block_importer extract-urls <url> <selector>` |
| `./retrieveSitemap <sitemap_url>` | `./text_block_importer sitemap <sitemap_url>` |

The original scripts (`createYaml.rb`, `makeYamls.sh`, `extractUrls.rb`, `retrieveSitemap`) remain available for backward compatibility, but we recommend using the new unified CLI for better maintainability and error handling.

## Architecture

The refactored version uses a modular Ruby architecture with:

- **Unified CLI**: Single command interface with subcommands
- **Error Handling**: Custom exception hierarchy with meaningful messages
- **HTTP Client**: Reusable client with retry logic and redirect handling
- **Modular Design**: Separate classes for scraping, YAML generation, and URL extraction
- **Configuration**: Centralized configuration management

## Contributing

Contributions are welcome! The tool has rough edges and can be improved. Feel free to submit pull requests or issues.

## License

This project is available as open source under the terms of the MIT License.
