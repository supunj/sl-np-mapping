#!/bin/sh

# Get the park name as the input
np=$1

# Project root
base_dir=$2

# Clean-up the tmp
rm $base_dir/tmp/*

# Create the hgt file list for the use with  gdalwrap
ls -1 $base_dir/dem/srtm/*.hgt > $base_dir/tmp/hgt-list.txt

set -- $(echo $($base_dir/script/get-bbox-for-park-polygon.sh $np $base_dir) | awk -F '[|]+' '{print $1, $2, $3, $4}')
echo "$1 $2 $3 $4"

# Extract only the elevation data for the given park polygon and write to a GeoTiff
gdalwarp -te $1 $2 $3 $4 -tr 0.000025 0.000025 -ot Float64 -r cubicspline --optfile $base_dir/tmp/hgt-list.txt $base_dir/tmp/$np-srtm.tiff

# Just print the meta-data for troubleshooting
gdalinfo $base_dir/tmp/$np-srtm.tiff > $base_dir/tmp/$np-srtm-panchromatic-meta.txt

# Monochrome hill shades
gdaldem hillshade -combined $base_dir/tmp/$np-srtm.tiff $base_dir/tmp/$np-srtm-panchromatic.tiff -z 1 -s 10000

# Colour map based on the relief cmap
gdaldem color-relief $base_dir/tmp/$np-srtm.tiff $base_dir/dem/$np-shaded-relief-cmap.txt $base_dir/tmp/$np-srtm-colour.tiff -z 1 -s 10000

# Combine the monochrome and colour reliefs - makes it look good
composite -dissolve 30% -gravity center $base_dir/tmp/$np-srtm-colour.tiff $base_dir/tmp/$np-srtm-panchromatic.tiff $base_dir/tmp/$np-srtm-combined.tiff

# Optional - Resize the image to a greater resolution - the resultant image will lose the geo information
# convert -adaptive-resize 1000% -density 600 -sharpen 0x1.2 -quality 100 -filter Mitchell $base_dir/tmp/$np-srtm.tiff $base_dir/tmp/$np-srtm-resized.tiff 

# Re-attach the goe information to the image
gdal_translate -a_srs EPSG:4326 -a_ullr $1 $4 $3 $2 $base_dir/tmp/$np-srtm-combined.tiff $base_dir/tmp/$np-srtm-combined-geo-referenced.tiff

# Cut out the exact park boundary polygon
gdalwarp -overwrite -cutline $base_dir/poly/$np-boundary-polygon.geojson -crop_to_cutline -dstalpha -cblend 0 $base_dir/tmp/$np-srtm-combined-geo-referenced.tiff $base_dir/tmp/$np-srtm-combined-geo-referenced-cropped.tiff