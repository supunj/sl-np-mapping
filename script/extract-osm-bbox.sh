#!/bin/sh

np=$1

# Project root
base_dir=$2

#Download if map does not exists
if ! [ -f "$base_dir/tmp/sri-lanka-latest.osm.pbf" ]; then
	echo "Downloading latest map...."
	wget --inet4-only -P $base_dir/tmp https://download.geofabrik.de/asia/sri-lanka-latest.osm.pbf
	echo "Download complete."
fi

# Get the national park
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
            --read-pbf file=$base_dir/tmp/sri-lanka-latest.osm.pbf \
        	--tf accept-nodes \
        	--tf accept-ways \
        	--tf accept-relations \
        	--tf reject-relations boundary=administrative \
			--tf reject-relations name="Sri Lanka" \
			--tf reject-relations name="Yala Forest Cover" \
			--tf reject-relations name="Yala National Park" \
			--tf reject-relations name="Bay of Bengal" \
			--tf reject-relations boundary=administrative \
            --used-node \
        	--bounding-polygon file=$base_dir/poly/$np.poly completeWays=yes \
        	--write-xml $base_dir/tmp/$np-cleansed-phase-1.osm

$HOME/.cargo/bin/poly2geojson < $base_dir/poly/$np.poly > $base_dir/tmp/$np.geojson

osmium extract \
			--polygon $base_dir/poly/$np.poly \
			--set-bounds \
			--strategy complete_ways \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/map/$np-cleansed.osm \
			$base_dir/tmp/$np-cleansed-phase-1.osm