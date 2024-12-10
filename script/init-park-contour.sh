#!/bin/sh

np=$1

# Project root
base_dir=$2

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
osmosis_bin=$(yq -r '.tool.osmosis.path' $base_dir/tmp/sl-np-mapping.yaml)
osmium_bin=$(yq -r '.tool.osmium.path' $base_dir/tmp/sl-np-mapping.yaml)

"$osmium_bin" extract \
			--polygon $base_dir/poly/$np-boundary-polygon.geojson \
			--strategy simple \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/tmp/$np-contours.osm \
			$base_dir/data/sl-contours.osm.pbf

"$osmosis_bin" \
            --read-xml file=$base_dir/tmp/$np-contours.osm \
  			--tag-filter reject-relations \
			--tag-filter accept-ways \
			--used-node \
			--write-xml $base_dir/map/$np-contours-cleansed.osm