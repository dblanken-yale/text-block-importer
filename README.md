# Text block importer

## What is this?

A neat way to get a list of sites and create YAML imports of the content so you
could import text block into a YaleSite that is using single content sync.

## How do I use it?

1. You must have a recent version of ruby, and nokogiri. You can install nokogiri with `gem install nokogiri`.
2. You'll then either create your own text file of urls or have it scour a web page to get them using the following command:
```bash
ruby extractUrls.rb <URL> <HTML Selector to look at>
```
3. Once you have that, you can run:
```bash
./makeYamls.sh <url text file> <HTML selector to scrape> <template file>
```

In the case of what's here, you'd use the `template.yml` file for the template file.

## What if I have a one-off page?

If you have a one off page you'd like to extract, you can run it manually with:
```bash
ruby createYaml.rb <URL> <html selector> <template file> <output file>
```

The above will create a new file, named whatever you named output file with a
copy of the template file with proper replacements done.

## What replacements are done?

{NAME} - The script attempts to find a h1 inside of what it scrapes to populate the title

{URL} - The script attempts to mimic the path to what it scraped for the new node's url

{UUID} - It generates a new unique UUID

{BLOCK_UUID} - It generates a new unique UUID for this as well

{REPLACEME} - This is where the content goes

## It's erroring for me.  What's up?

Let me know, although this has a lot of rough edges.  If you'd like to
contribute, please feel free!
