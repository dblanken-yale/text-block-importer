#!/bin/bash

# If file not given, exit.
if [ -z "$1" ]; then
  echo "No url file given."
  exit 1
fi

i=1

# For each line inside of the file, call the createYaml.rb script.
while IFS='' read -r line || [[ -n "$line" ]]; do
  echo "Creating yaml for $line"
  # remove \n from line.
  line=$(echo "$line" | tr -d '\n')
  ruby createYaml.rb "$line" "$2" "$3" "node-$i.output.yml"
  i=$((i + 1))
done < "$1"
