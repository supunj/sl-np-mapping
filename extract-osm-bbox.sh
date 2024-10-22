#!/bin/sh

np=$1

# Project root
base_dir="$(dirname "$(readlink -f "$0")")"

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
        	--tf reject-ways boundary=administrative \
        	--tf accept-relations \
        	--tf reject-relations boundary=administrative \
            --used-node \
        	--bounding-polygon file=$base_dir/poly/$np.poly \
        	--write-xml $base_dir/map/$np-cleansed.osm