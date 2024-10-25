#!/bin/sh

# Get the park name as the input
np=$1

# Project root
base_dir="$(dirname "$(readlink -f "$0")")"

# Clean-up the tmp
rm $base_dir/tmp/*

# Create the hgt file list for the use with  gdalwrap
ls -1 $base_dir/data/srtm/*.hgt > $base_dir/tmp/hgt-list.txt

set -- $(echo $($base_dir/get-bbox-for-park-polygon.sh $np) | awk -F '[|]+' '{print $1, $2, $3, $4}')
echo "$1 $2 $3 $4" 

# Extract only the elevation data for the given park plygon and write to a GeoTiff
gdalwarp -te $1 $2 $3 $4 -r cubicspline --optfile $base_dir/tmp/hgt-list.txt $base_dir/tmp/$np-srtm.tiff

gdaldem hillshade -combined $base_dir/tmp/$np-srtm.tiff $base_dir/tmp/$np-srtm-panchromatic.tiff -z 0.001 -s 5000

# gdalinfo $base_dir/tmp/$np-srtm-panchromatic.tiff > $base_dir/tmp/$np-srtm-panchromatic-meta.txt

gdaldem color-relief $base_dir/tmp/$np-srtm.tiff $base_dir/colour/$np-shaded-relief-cmap.txt $base_dir/tmp/$np-srtm-colour.tiff -z 0.001 -s 5000

composite -dissolve 30% -gravity center $base_dir/tmp/$np-srtm-colour.tiff $base_dir/tmp/$np-srtm-panchromatic.tiff $base_dir/tmp/$np-srtm-final.tiff

# Resize the image to a greater resolution - the resultant image will lose the geo information
convert -adaptive-resize 1000% -density 600 -sharpen 0x1.2 -quality 100 -filter Mitchell $base_dir/tmp/$np-srtm-final.tiff $base_dir/tmp/$np-srtm-final-resized.tiff 

# Re-attach the goe information to the image
gdal_translate -a_srs EPSG:4326 -a_ullr $1 $4 $3 $2 $base_dir/tmp/$np-srtm-final-resized.tiff $base_dir/tmp/$np-srtm-final-resized-geo-referenced.tiff

# Cut out the exact park boundary polygon
gdalwarp -cutline $base_dir/poly/$np-boundary-polygon.geojson -crop_to_cutline -dstalpha $base_dir/tmp/$np-srtm-final-resized-geo-referenced.tiff $base_dir/raster/$np-srtm-final-resized-geo-referenced-cropped.tiff