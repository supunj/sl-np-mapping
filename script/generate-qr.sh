#!/bin/sh

# Project root
base_dir=$2

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
qrencode_bin=$(yq -r '.tool.qrencode.path' $base_dir/tmp/sl-np-mapping.yaml)

"$qrencode_bin" -S -v 12 -l H -d 300 -t SVG --rle --svg-path --foreground=346751ff --background=FFFFFF00 -r $base_dir/info.txt -o $base_dir/info.svg