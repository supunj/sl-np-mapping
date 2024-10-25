#!/bin/sh

np=$1

# Project root
base_dir="$(dirname "$(readlink -f "$0")")"

osmium extract \
			--polygon $base_dir/poly/$np-boundary-polygon.geojson \
			--strategy simple \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/tmp/$np-contours.osm \
			$base_dir/data/sl-contours.osm.pbf

$base_dir/tool/osmosis-0.49.2/bin/osmosis \
            --read-xml file=$base_dir/tmp/$np-contours.osm \
  			--tag-filter reject-relations \
			--tag-filter accept-ways \
			--used-node \
			--write-xml $base_dir/map/$np-contours-cleansed.osm