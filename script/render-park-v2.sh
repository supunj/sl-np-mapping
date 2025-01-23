#!/bin/sh

np=$1

# Project root
base_dir=$2

# Create runtime folders if they don't exist
# mkdir -p $base_dir/tmp
# mkdir -p $base_dir/var

# # Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
# rsvg_convert_bin=$(yq -r '.tool.rsvg_convert.path' $base_dir/tmp/sl-np-mapping.yaml)
# svgo_bin=$(yq -r '.tool.svgo.path' $base_dir/tmp/sl-np-mapping.yaml)
# inkscape_bin=$(yq -r '.tool.inkscape.path' $base_dir/tmp/sl-np-mapping.yaml)
python3_bin=$(yq -r '.tool.python.python3.path' $base_dir/tmp/sl-np-mapping.yaml)

"$python3_bin" $base_dir/tool/generate-qgis-print-layout.py