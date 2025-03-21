#!/bin/sh
set -eu

# Get the park name as the input
np=$1

# Project root
base_dir=$2

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Clean-up the tmp
rm -rf $base_dir/tmp/*

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
gdalwarp_hillshade_tr=$(yq -r '.park.'$np'.gdalwarp_hillshade_tr' $base_dir/tmp/sl-np-mapping.yaml)
gdaldem_hillshade_factor=$(yq -r '.park.'$np'.gdaldem_hillshade_factor' $base_dir/tmp/sl-np-mapping.yaml)
gdaldem_hillshade_scale=$(yq -r '.park.'$np'.gdaldem_hillshade_scale' $base_dir/tmp/sl-np-mapping.yaml)
composite_hillshade_dissolve=$(yq -r '.park.'$np'.composite_hillshade_dissolve' $base_dir/tmp/sl-np-mapping.yaml)
convert_boundary_glow_colour=$(yq -r '.park.'$np'.convert_boundary_glow_colour' $base_dir/tmp/sl-np-mapping.yaml)
convert_boundary_glow_blur=$(yq -r '.park.'$np'.convert_boundary_glow_blur' $base_dir/tmp/sl-np-mapping.yaml)
convert_boundary_glow_level=$(yq -r '.park.'$np'.convert_boundary_glow_level' $base_dir/tmp/sl-np-mapping.yaml)
convert_crop_tile_width=$(yq -r '.park.'$np'.convert_crop_tile_width' $base_dir/tmp/sl-np-mapping.yaml)
convert_crop_tile_height=$(yq -r '.park.'$np'.convert_crop_tile_height' $base_dir/tmp/sl-np-mapping.yaml)
montage_bin=$(yq -r '.tool.imagemagick.montage.path' $base_dir/tmp/sl-np-mapping.yaml)
park_glow_raster_reduce_by_px=$(yq -r '.park.'$np'.park_glow_raster_reduce_by_px' $base_dir/tmp/sl-np-mapping.yaml)
convert_limit_param=$(yq -r '.tool.imagemagick.convert.limit_param' $base_dir/tmp/sl-np-mapping.yaml)
vips_bin=$(yq -r '.tool.libvips.vips.path' $base_dir/tmp/sl-np-mapping.yaml)
vipsheader_bin=$(yq -r '.tool.libvips.vipsheader.path' $base_dir/tmp/sl-np-mapping.yaml)
vips_tile_size=$(yq -r '.tool.libvips.vips.tile_size' $base_dir/tmp/sl-np-mapping.yaml)

# Experimental enhancing of the hill-shading background image
"$ogr2ogr_bin" \
              -f SQLite \
              -dsco SPATIALITE=YES \
              -lco GEOMETRY_NAME=geom \
              -nln $np"_poly" \
              $base_dir/tmp/$np-map-extent.db \
              $base_dir/var/$np.geojson

sed 's/{$np}/'$np'/g' $base_dir/script/create-shaded-relief-extent.sql > $base_dir/tmp/create-shaded-relief-extent.sql

"$spatialite_bin" \
              $base_dir/tmp/$np-map-extent.db < $base_dir/tmp/create-shaded-relief-extent.sql

"$ogr2ogr_bin" \
              -f GeoJSON \
              $base_dir/tmp/$np-shaded-relief-map-extent.geojson \
              $base_dir/tmp/$np-map-extent.db $np"_poly"

# Full extent of the map polygon
map_extent_poly=$base_dir/tmp/$np-shaded-relief-map-extent.geojson

echo "1. Map extent GeoJSON generated"

# Create the hgt file list for the use with  gdalwrap
ls -1 $base_dir/dem/srtm/*.hgt > $base_dir/tmp/hgt-list.txt

set -- $(echo $($base_dir/script/get-bbox-for-polygon.sh $map_extent_poly $base_dir) | awk -F '[|]+' '{print $1, $2, $3, $4}')
echo "$1 $2 $3 $4"

# Extract only the elevation data for the given park bounding box and write to a GeoTiff
"$gdalwarp_bin" \
              -te $1 $2 $3 $4 \
              -tr $gdalwarp_hillshade_tr \
              -ot Float64 \
              -r cubicspline \
              --optfile $base_dir/tmp/hgt-list.txt \
              $base_dir/tmp/$np-srtm.tiff

# Just print the meta-data for troubleshooting
"$gdalinfo_bin" \
              $base_dir/tmp/$np-srtm.tiff > $base_dir/tmp/$np-srtm-panchromatic-meta.txt

echo "2. Elevation data extracted for the map extent polygon."

# Monochrome hill shades
"$gdaldem_bin" \
              hillshade \
              -compute_edges \
              -igor \
              $base_dir/tmp/$np-srtm.tiff \
              $base_dir/tmp/$np-srtm-panchromatic.tiff \
              -z $gdaldem_hillshade_factor \
              -s $gdaldem_hillshade_scale

echo "3. Monochrome elevation map created."

# Colour map based on the relief cmap
"$gdaldem_bin" \
              color-relief \
              $base_dir/tmp/$np-srtm.tiff \
              $base_dir/dem/$np-shaded-relief-cmap.txt \
              $base_dir/tmp/$np-srtm-colour.tiff \
              -z $gdaldem_hillshade_factor \
              -s $gdaldem_hillshade_scale

echo "4. Colour elevation map created."

"$vips_bin" \
            dzsave \
            $base_dir/tmp/$np-srtm-panchromatic.tiff \
            $base_dir/tmp/$np-mono-tile \
            --tile-size $vips_tile_size \
            --overlap 0 \
            --depth one \
            --suffix .tiff

echo "5. Monochrome elevation map was split for easier processing."

"$vips_bin" \
            dzsave \
            $base_dir/tmp/$np-srtm-colour.tiff \
            $base_dir/tmp/$np-colour-tile \
            --tile-size $vips_tile_size \
            --overlap 0 \
            --depth one \
            --suffix .tiff

echo "6. Colour elevation map was split for easier processing."

echo "Blending panchromatic and colour images...."
for tile in $base_dir/tmp/$np-mono-tile_files/0/*; do
  tile_file_name=$(basename $tile)
  "$composite_bin" \
              -dissolve $composite_hillshade_dissolve \
              -gravity center \
              $base_dir/tmp/$np-colour-tile_files/0/$tile_file_name \
              $tile \
              $base_dir/tmp/$np-srtm-combined-tile-$tile_file_name
done

echo "7. The two sets of images were blended."

# Combine them again
tiles=$(ls $base_dir/tmp/$np-srtm-combined-tile-*.tiff | \
        sed -E 's/.*tile-([0-9]+)_([0-9]+)\..*/\2 \1 &/' | \
        sort -n -k1 -k2 | \
        awk '{print $NF}')
across=$(ls $base_dir/tmp/$np-srtm-combined-tile-*_0.tiff | wc -l) # Get the highest column index

vips arrayjoin "$tiles" $base_dir/tmp/$np-srtm-combined.tiff --across $across

echo "8. Blended image tiles were combined."

# Re-attach the geo information to the image - this is a temporary measure to make the -cutline work as later on we will lose geo data when we do the convert
"$gdal_translate_bin" \
              -a_srs EPSG:4326 \
              -a_ullr $1 $4 $3 $2 \
              $base_dir/tmp/$np-srtm-combined.tiff \
              $base_dir/tmp/$np-srtm-combined-geo-referenced.tiff

echo "9. Re-attached geo data to the combined blended image."

# Cut out the exact park boundary polygon
"$gdalwarp_bin" \
              -overwrite \
              -cutline $base_dir/var/$np-boundary-polygon.geojson \
              -dstalpha \
              -cblend 0 \
              $base_dir/tmp/$np-srtm-combined-geo-referenced.tiff \
              $base_dir/var/$np-hillshade-park-polygon.tiff

echo "10. Park polygon was cut out from the blended image."

# Create an empty white image, compress, re-attach the geo data and apply the cut-line - this is to be used for creating the glow around the park boundary
echo "Generating park's outer glow...."

image_width=$("$vipsheader_bin" -f width $base_dir/var/$np-hillshade-park-polygon.tiff 2>/dev/null)
image_height=$("$vipsheader_bin" -f height $base_dir/var/$np-hillshade-park-polygon.tiff 2>/dev/null)

"$convert_bin" \
              -size "$((image_width - $park_glow_raster_reduce_by_px))"x"$((image_height - $park_glow_raster_reduce_by_px))" canvas:white \
              -compress lzw \
              -depth 8 $base_dir/tmp/$np-glow.tiff

echo "11. Created a blank white to be used with park's outer glow."

"$gdal_translate_bin" \
              -a_srs EPSG:4326 \
              -a_ullr $1 $4 $3 $2 $base_dir/tmp/$np-glow.tiff \
              $base_dir/tmp/$np-glow-geo-referenced.tiff

echo "12. Attached geo data to the white blank image."

"$gdalwarp_bin" \
              -overwrite \
              -cutline $base_dir/var/$np-boundary-polygon.geojson \
              -dstalpha \
              -cblend 0 $base_dir/tmp/$np-glow-geo-referenced.tiff \
              $base_dir/tmp/$np-glow-geo-referenced-cropped.tiff

echo "13. Park polygon was cut out from the white blank image."

# Add the glow...this may take time
"$convert_bin" \
                $convert_limit_param \
                $base_dir/tmp/$np-glow-geo-referenced-cropped.tiff \
                \(  +clone \
                  -channel A  \
                  -blur $convert_boundary_glow_blur \
                  -level $convert_boundary_glow_level \
                  +channel \
                  +level-colors "$convert_boundary_glow_colour" \
                \) \
                -compose DstOver \
                -composite \
                $base_dir/tmp/$np-glow-cropped-applied.tiff

echo "14. Added the glow to the white cut-out."

# Replace the white with transparency
"$convert_bin" \
                $base_dir/tmp/$np-glow-cropped-applied.tiff \
                -fuzz 10% \
                -transparent white \
                $base_dir/tmp/$np-glow-cropped-applied-transparent.tiff

echo "15. Replaced the white with transparency."

# Geo-reference it again
"$gdal_translate_bin" \
                -a_srs EPSG:4326 \
                -a_ullr $1 $4 $3 $2 \
                $base_dir/tmp/$np-glow-cropped-applied-transparent.tiff \
                $base_dir/var/$np-park-polygon-glow.tiff

echo "16. Re-attached geo data to the final park glow image."