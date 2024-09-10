#!/bin/bash

# If file not given, exit.
if [ -z "$1" ]; then
  echo "No url file given."
  exit 1
fi

# if -h is the only argument, print help message.
if [ "$1" == "-h" ]; then
  echo "Usage: makeYamls.sh <url file> <html selector> <template file> [--use-domains]"
  echo "  <url file>       File containing urls to scrape."
  echo "  <html selector>  The html selector to scrape."
  echo "  <template file>  The template file to use."
  echo "  --use-domains    Use this flag if you want to replace relative URLs with the domain of the page scraped from."
  exit 0
fi

if [ -z "$2" ]; then
  echo "No html selector given."
  exit 1
fi

if [ -z "$3" ]; then
  echo "No template file given."
  exit 1
fi

# If args contain --use-domains, set the variable to true.
if [[ $@ == *"--use-domains"* ]]; then
  useDomains="--use-domains"
else
  useDomains=""
fi

i=1

# For each line inside of the file, call the createYaml.rb script.
while IFS='' read -r line || [[ -n "$line" ]]; do
  echo "Creating yaml for $line"
  # remove \n from line.
  line=$(echo "$line" | tr -d '\n')
  ruby createYaml.rb "$line" "$2" "$3" "node-$i.output.yml" "$useDomains"
  i=$((i + 1))
done <"$1"
