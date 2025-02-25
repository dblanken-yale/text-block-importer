# Text Block Importer

A tool for importing web content into YaleSite text blocks through YAML files, specifically designed for single content sync implementations.

## Overview

Text Block Importer is a set of Ruby and shell scripts that helps you:

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

3. Make the shell scripts executable:
   ```bash
   chmod +x makeYamls.sh retrieveSitemap
   ```

## Usage

The tool offers several ways to extract and process content:

### 1. Extracting URLs from a Page

To extract URLs from a page using a CSS selector:

```bash
ruby extractUrls.rb <URL> <CSS selector>
```

Example:
```bash
ruby extractUrls.rb https://example.yale.edu/policies .content-main
```

This will output a list of URLs that can be saved to a file for further processing.

### 2. Creating a Single YAML File

To create a YAML file for a single page:

```bash
ruby createYaml.rb <URL> <CSS selector> <template file> <output file> [--use-domains]
```

Example:
```bash
ruby createYaml.rb https://example.yale.edu/page.html "main .content" template.yml output.yml
```

Options:
- `--use-domains`: Replace relative URLs with the full domain path from the source website

### 3. Processing Multiple URLs

To process multiple URLs and create YAML files for each:

```bash
./makeYamls.sh <url_file> <CSS selector> <template file> [--use-domains]
```

Example:
```bash
./makeYamls.sh urls.txt ".main-content" template.yml --use-domains
```

This will generate numbered YAML files (node-1.output.yml, node-2.output.yml, etc.) for each URL in the input file.

### 4. Processing a Sitemap

To extract URLs from a sitemap:

```bash
./retrieveSitemap <sitemap URL>
```

Example:
```bash
./retrieveSitemap https://example.yale.edu/sitemap.xml
```

This will create a `sitemap.links` file containing all URLs from the sitemap, which can then be used with `makeYamls.sh`.

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
   ./retrieveSitemap https://example.yale.edu/sitemap.xml
   ```

2. Process all URLs from the sitemap:
   ```bash
   ./makeYamls.sh sitemap.links ".content-main" template.yml
   ```

3. Import the resulting YAML files into your YaleSite instance using the single content sync process.

## Troubleshooting

If you encounter issues:

- No content extracted: Check if your CSS selector is correct. The tool will show warnings when no content is found.
- XML parsing errors: Make sure you have libxml2 installed for sitemap processing.
- Script execution errors: Ensure scripts have execute permissions (`chmod +x script_name`).

## Contributing

Contributions are welcome! The tool has rough edges and can be improved. Feel free to submit pull requests or issues.

## License

This project is available as open source under the terms of the MIT License.
