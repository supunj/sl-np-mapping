#!/bin/sh

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
gdalwarp_bin=$(yq -r '.tool.gdal.gdalwarp.path' $base_dir/tmp/sl-np-mapping.yaml)
poly2geojson_bin=$(yq -r '.tool.poly2geojson.path' $base_dir/tmp/sl-np-mapping.yaml)
python3_bin=$(yq -r '.tool.python.python3.path' $base_dir/tmp/sl-np-mapping.yaml)
gdal_contour_bin=$(yq -r '.tool.gdal.gdal_contour.path' $base_dir/tmp/sl-np-mapping.yaml)
np_boundary_name=$(yq -r '.park.'$np'.boundary_name' $base_dir/tmp/sl-np-mapping.yaml)
np_boundary_tag=$(yq -r '.park.'$np'.boundary_tag' $base_dir/tmp/sl-np-mapping.yaml)
elevation_interval=$(yq -r '.park.'$np'.elevation_interval' $base_dir/tmp/sl-np-mapping.yaml)

# Clean-up the tmp
rm $base_dir/tmp/*

#Download if map does not exists
if ! [ -f "$base_dir/var/sri-lanka-latest.osm.pbf" ]; then
	echo "Downloading latest map...."
	wget --inet4-only -P $base_dir/var https://download.geofabrik.de/asia/sri-lanka-latest.osm.pbf
	echo "Download complete."
fi

# Create the geojson and osm from the extract poly files for later use
"$poly2geojson_bin" < $base_dir/poly/sri-lanka.poly > $base_dir/var/sri-lanka.geojson
"$poly2geojson_bin" < $base_dir/poly/$np.poly > $base_dir/var/$np.geojson

# Get the national park
"$osmosis_bin" \
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

"$osmium_bin" extract \
			--polygon $base_dir/poly/$np.poly \
			--set-bounds \
			--strategy complete_ways \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/tmp/$np-cleansed.osm \
			$base_dir/tmp/$np-cleansed-phase-1.osm

"$osmium_bin" tags-filter \
			-O \
			-o $base_dir/tmp/$np-boundary-polygon.osm \
			$base_dir/tmp/$np-cleansed.osm \
			"boundary=national_park" \
  			"n/name=$np_boundary_name" \
  			"r/$np_boundary_tag"

"$osmium_bin" export --geometry-types=polygon $base_dir/tmp/$np-boundary-polygon.osm -O -o $base_dir/var/$np-boundary-polygon.geojson

# Create the background polygon from the .poly file
"$python3_bin" $base_dir/tool/poly-to-osm.py $np $base_dir/poly/$np.poly $base_dir/tmp/$np-background.osm

# Extract the coastline and insert into SpatiaLite for later use
"$osmosis_bin" \
			--read-pbf file=$base_dir/var/sri-lanka-latest.osm.pbf \
			--tf accept-ways natural=coastline \
			--tf accept-relations place=island \
			--bounding-polygon file=$base_dir/poly/sri-lanka.poly \
			--used-node \
			--write-xml $base_dir/var/sl-coastline.osm

# Admin boundaries
"$osmium_bin" tags-filter \
            -O \
            -o $base_dir/tmp/sl-admin-raw.osm \
            $base_dir/var/sri-lanka-latest.osm.pbf \
            wr/boundary=administrative

"$osmium_bin" extract \
			--polygon $base_dir/poly/sri-lanka.poly \
			--set-bounds \
			--strategy simple \
			--clean uid --clean user --clean changeset \
			-O \
			-o $base_dir/var/sl-admin.osm \
			$base_dir/tmp/sl-admin-raw.osm

# Surrounding forests
"$osmosis_bin" \
            --read-pbf file=$base_dir/var/sri-lanka-latest.osm.pbf \
			--tf accept-relations natural="wood" landuse="forest" \
        	--bounding-polygon file=$base_dir/poly/$np.poly completeWays=yes \
			completeRelations=yes \
			--used-node \
			--used-way \
        	--write-xml $base_dir/tmp/$np-surrounding-forests-phase-1.osm

"$osmium_bin" tags-filter \
            -O \
            -o $base_dir/var/$np-surrounding-forests.osm \
            $base_dir/tmp/$np-surrounding-forests-phase-1.osm \
            wr/natural=wood

# Surrounding protected areas
"$osmosis_bin" \
            --read-pbf file=$base_dir/var/sri-lanka-latest.osm.pbf \
			--tf accept-relations type="boundary" \
			--tf accept-relations boundary="protected_area,national_park" \
        	--bounding-polygon file=$base_dir/poly/$np.poly \
			completeWays=yes \
			completeRelations=yes \
			--used-node \
			--used-way \
        	--write-xml $base_dir/tmp/$np-surrounding-protected-areas-phase-1.osm

"$osmium_bin" tags-filter \
            -O \
            -o $base_dir/var/$np-surrounding-protected-areas.osm \
            $base_dir/tmp/$np-surrounding-protected-areas-phase-1.osm \
            wr/type=boundary \
			wr/boundary=*

# Merge OSM data, contours and the background polygon
"$osmosis_bin" \
            --read-xml file=$base_dir/tmp/$np-cleansed.osm \
			--read-xml file=$base_dir/tmp/$np-background.osm \
			--sort \
			--merge \
        	--bounding-polygon file=$base_dir/poly/$np.poly completeWays=yes \
        	--write-xml $base_dir/var/$np-cleansed-merged.osm

# Create the hgt file list for the use with  gdalwrap
ls -1 $base_dir/dem/srtm/*.hgt > $base_dir/tmp/hgt-list.txt

set -- $(echo $($base_dir/script/get-bbox-for-polygon.sh $base_dir/var/$np.geojson $base_dir) | awk -F '[|]+' '{print $1, $2, $3, $4}')
echo "$1 $2 $3 $4" 

# Extract only the elevation data for the given park polygon and write to a GeoTiff
"$gdalwarp_bin" -overwrite -te $1 $2 $3 $4 -tr 0.000025 0.000025 -ot Float64 -r cubicspline --optfile $base_dir/tmp/hgt-list.txt $base_dir/var/$np-srtm.tiff

# Generate contours and keep them in a .shp file 
"$gdal_contour_bin" -a elev -i $elevation_interval -nln contour $base_dir/var/$np-srtm.tiff $base_dir/var/sl-contour.shp