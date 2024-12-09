#!/bin/sh

np=$1

# Project root
base_dir=$2

# Clean-up the tmp
rm $base_dir/tmp/*

#Download if map does not exists
if ! [ -f "$base_dir/var/sri-lanka-latest.osm.pbf" ]; then
	echo "Downloading latest map...."
	wget --inet4-only -P $base_dir/var https://download.geofabrik.de/asia/sri-lanka-latest.osm.pbf
	echo "Download complete."
fi

# Create the geojson and osm from the extract poly files for later use
$HOME/.cargo/bin/poly2geojson < $base_dir/poly/sri-lanka.poly > $base_dir/poly/sri-lanka.geojson
$HOME/.cargo/bin/poly2geojson < $base_dir/poly/$np.poly > $base_dir/poly/$np.geojson

# Get the national park
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
            --read-pbf file=$base_dir/var/sri-lanka-latest.osm.pbf \
        	--tf accept-nodes \
        	--tf accept-ways \
        	--tf accept-relations \
        	--tf reject-relations boundary=administrative \
			--tf reject-relations name="Sri Lanka" \
			--tf reject-relations name="Yala Forest Cover" \
			--tf reject-relations name="Yala National Park" \
			--tf reject-relations name="Bay of Bengal" \
			--tf reject-relations boundary=administrative \
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

# Create the background polygon from the .poly file
python3 $base_dir/script/poly-to-osm.py $np $base_dir/poly/$np.poly $base_dir/tmp/$np-background.osm

# Extract the coastline and insert into SpatiaLite for later use
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
			--read-pbf file=$base_dir/var/sri-lanka-latest.osm.pbf \
			--tf accept-ways natural=coastline \
			--tf accept-relations place=island \
			--bounding-polygon file=$base_dir/poly/sri-lanka.poly \
			--used-node \
			--write-xml $base_dir/var/sl-coastline.osm

# Admin boundaries
osmium tags-filter \
            -O \
            -o $base_dir/tmp/sl-admin-raw.osm \
            $base_dir/var/sri-lanka-latest.osm.pbf \
            wr/boundary=administrative

osmium extract \
			--polygon $base_dir/poly/sri-lanka.poly \
			--set-bounds \
			--strategy simple \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/var/sl-admin.osm \
			$base_dir/tmp/sl-admin-raw.osm

# Merge OSM data, contours and the background polygon
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
            --read-xml file=$base_dir/map/$np-cleansed.osm \
			--read-xml file=$base_dir/tmp/$np-background.osm \
			--sort \
			--merge \
        	--bounding-polygon file=$base_dir/poly/$np.poly completeWays=yes \
        	--write-xml $base_dir/var/$np-cleansed-merged.osm

# Create the hgt file list for the use with  gdalwrap
ls -1 $base_dir/dem/srtm/*.hgt > $base_dir/tmp/hgt-list.txt

set -- $(echo $($base_dir/script/get-bbox-for-polygon.sh $base_dir/poly/$np.geojson) | awk -F '[|]+' '{print $1, $2, $3, $4}')
echo "$1 $2 $3 $4" 

# Extract only the elevation data for the given park polygon and write to a GeoTiff
gdalwarp -overwrite -te $1 $2 $3 $4 -tr 0.000025 0.000025 -ot Float64 -r cubicspline --optfile $base_dir/tmp/hgt-list.txt $base_dir/var/$np-srtm.tiff