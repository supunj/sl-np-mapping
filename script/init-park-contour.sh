#!/bin/sh
set -eu

np=$1

# Project root
base_dir=$2

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
osmosis_bin=$(yq -r '.tool.osmosis.path' $base_dir/tmp/sl-np-mapping.yaml)
osmium_bin=$(yq -r '.tool.osmium.path' $base_dir/tmp/sl-np-mapping.yaml)

"$osmium_bin" extract \
			--polygon $base_dir/var/$np-boundary-polygon.geojson \
			--strategy simple \
			--clean uid \
			--clean user \
			--clean changeset \
			-O \
			-o $base_dir/tmp/$np-contours.osm \
			$base_dir/var/sl-contours.osm.pbf

"$osmosis_bin" \
            --read-xml file=$base_dir/tmp/$np-contours.osm \
  			--tag-filter reject-relations \
			--tag-filter accept-ways \
			--used-node \
			--write-xml $base_dir/map/$np-contours-cleansed.osm