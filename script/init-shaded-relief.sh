#!/bin/sh

# Get the park name as the input
np=$1

# Project root
base_dir=$2

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Clean-up the tmp
rm $base_dir/tmp/*

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
ogr2ogr_bin=$(yq -r '.tool.gdal.ogr2ogr.path' $base_dir/tmp/sl-np-mapping.yaml)
spatialite_bin=$(yq -r '.tool.spatialite.path' $base_dir/tmp/sl-np-mapping.yaml)
gdalwarp_bin=$(yq -r '.tool.gdal.gdalwarp.path' $base_dir/tmp/sl-np-mapping.yaml)
gdalinfo_bin=$(yq -r '.tool.gdal.gdalinfo.path' $base_dir/tmp/sl-np-mapping.yaml)
gdaldem_bin=$(yq -r '.tool.gdal.gdaldem.path' $base_dir/tmp/sl-np-mapping.yaml)
gdal_translate_bin=$(yq -r '.tool.gdal.gdal_translate.path' $base_dir/tmp/sl-np-mapping.yaml)
composite_bin=$(yq -r '.tool.imagemagick.composite.path' $base_dir/tmp/sl-np-mapping.yaml)
convert_bin=$(yq -r '.tool.imagemagick.convert.path' $base_dir/tmp/sl-np-mapping.yaml)

# Experimental enhancing of the hill-shading background image
"$ogr2ogr_bin" -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -nln $np"_poly" $base_dir/tmp/$np-map-extent.db $base_dir/poly/$np.geojson
sed 's/{$np}/'$np'/g' $base_dir/script/create-shaded-relief-extent.sql > $base_dir/tmp/create-shaded-relief-extent.sql
"$spatialite_bin" $base_dir/tmp/$np-map-extent.db < $base_dir/tmp/create-shaded-relief-extent.sql
"$ogr2ogr_bin" -f GeoJSON $base_dir/tmp/$np-shaded-relief-map-extent.geojson $base_dir/tmp/$np-map-extent.db $np"_poly"

# Full extent of the map polygon
map_extent_poly=$base_dir/tmp/$np-shaded-relief-map-extent.geojson

# Create the hgt file list for the use with  gdalwrap
ls -1 $base_dir/dem/srtm/*.hgt > $base_dir/tmp/hgt-list.txt

set -- $(echo $($base_dir/script/get-bbox-for-polygon.sh $map_extent_poly $base_dir) | awk -F '[|]+' '{print $1, $2, $3, $4}')
echo "$1 $2 $3 $4"

# Extract only the elevation data for the given park polygon and write to a GeoTiff
"$gdalwarp_bin" -te $1 $2 $3 $4 -tr 0.000025 0.000025 -ot Float64 -r cubicspline --optfile $base_dir/tmp/hgt-list.txt $base_dir/tmp/$np-srtm.tiff

# Just print the meta-data for troubleshooting
"$gdalinfo_bin" $base_dir/tmp/$np-srtm.tiff > $base_dir/tmp/$np-srtm-panchromatic-meta.txt

# Monochrome hill shades
"$gdaldem_bin" hillshade -compute_edges -igor $base_dir/tmp/$np-srtm.tiff $base_dir/tmp/$np-srtm-panchromatic.tiff -z 1 -s 10000

# Colour map based on the relief cmap
"$gdaldem_bin" color-relief $base_dir/tmp/$np-srtm.tiff $base_dir/dem/$np-shaded-relief-cmap.txt $base_dir/tmp/$np-srtm-colour.tiff -z 1 -s 10000

# Combine the monochrome and colour reliefs - makes it look good
"$composite_bin" -dissolve 30% -gravity center $base_dir/tmp/$np-srtm-colour.tiff $base_dir/tmp/$np-srtm-panchromatic.tiff $base_dir/tmp/$np-srtm-combined.tiff

# Trying with a mask
#convert $base_dir/tmp/$np-srtm-combined.tiff -density 600 -sharpen 0x1.2 -quality 100 -bordercolor black -fill \#eeeeee \( -clone 0 -colorize 100 -shave 500x500 -border 500x500 -blur 0x500 \) -compose copyopacity -composite $base_dir/tmp/$np-srtm-combined-transparent.tiff

# Optional - Resize the image to a greater resolution - the resultant image will lose the geo information
# convert -adaptive-resize 1000% -density 600 -sharpen 0x1.2 -quality 100 -filter Mitchell $base_dir/tmp/$np-srtm.tiff $base_dir/tmp/$np-srtm-resized.tiff

# Re-attach the goe information to the image - this is a temporary measure to make the -cutline work as later on we will lose geo data when we do the convert
"$gdal_translate_bin" -a_srs EPSG:4326 -a_ullr $1 $4 $3 $2 $base_dir/tmp/$np-srtm-combined.tiff $base_dir/tmp/$np-srtm-combined-geo-referenced.tiff

# Cut out the exact park boundary polygon
"$gdalwarp_bin" -overwrite -cutline $base_dir/poly/$np-boundary-polygon.geojson -dstalpha -cblend 0 $base_dir/tmp/$np-srtm-combined-geo-referenced.tiff $base_dir/tmp/$np-srtm-combined-cropped.tiff

# Add a fading glow to the boundary for 
"$convert_bin" $base_dir/tmp/$np-srtm-combined-cropped.tiff \(  +clone \
              -channel A  -blur 0x200.5 -level 0,80% +channel \
              +level-colors "#606c38" \
            \) -compose DstOver -composite $base_dir/tmp/$np-srtm-combined-cropped-halo.tiff

# Re-attach the geo information to the image
"$gdal_translate_bin" -a_srs EPSG:4326 -a_ullr $1 $4 $3 $2 $base_dir/tmp/$np-srtm-combined-cropped-halo.tiff $base_dir/var/$np-srtm-combined-cropped-halo-geo-referenced.tiff
