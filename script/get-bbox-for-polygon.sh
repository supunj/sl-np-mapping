#!/bin/sh
set -eu

polygon=$1 # .geojson

# Project root
base_dir=$2

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
ogrinfo_bin=$(yq -r '.tool.gdal.ogrinfo.path' $base_dir/tmp/sl-np-mapping.yaml)

# Extract the extent line using grep and then process it with awk
extent_line=$(echo "$("$ogrinfo_bin" -al -geom=NO $polygon)" | grep "Extent:")

if [ -n "$extent_line" ]; then
    set -- $(echo "$extent_line" | awk -F '[(), -]+' '{print $2, $3, $4, $5}')
    echo "$1|$2|$3|$4"
else
    echo "Extent not found."
fi
