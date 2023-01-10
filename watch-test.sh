#!/bin/bash


while [ true ]; do
  changed="$(inotifywait -e close_write,modify,delete -r --format "%w" src)"
  echo "changed $changed"
  zig test src/test.zig
done

