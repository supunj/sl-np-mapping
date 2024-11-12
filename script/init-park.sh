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

osmium extract \
			--polygon $base_dir/poly/$np.poly \
			--set-bounds \
			--strategy complete_ways \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/map/$np-cleansed.osm \
			$base_dir/tmp/$np-cleansed-phase-1.osm

# Create the geojson and osm from the extract poly for later use
$HOME/.cargo/bin/poly2geojson < $base_dir/poly/$np.poly > $base_dir/poly/$np.geojson
#ogr2ogr -of "OSM" $base_dir/poly/$np.osm $base_dir/poly/$np.geojson

# Extract the exact park boundary to geojson for later use
case "$np" in
    "lahugala") name="Lahugala Kitulana National Park";;
    "kumana") name="Kumana National Park";;
    "yb1") name="Yala National Park - Block 1";;
    *) break;;
esac

osmium tags-filter \
			-O \
			-o $base_dir/tmp/$np-boundary-polygon.osm \
			$base_dir/map/$np-cleansed.osm \
			"boundary=national_park" \
  			"n/name=$name" \
  			"r/type=boundary"

osmium export --geometry-types=polygon $base_dir/tmp/$np-boundary-polygon.osm -O -o $base_dir/poly/$np-boundary-polygon.geojson