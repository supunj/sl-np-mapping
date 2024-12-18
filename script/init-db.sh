
#!/bin/sh

np=$1

# Project root
base_dir=$2

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var
mkdir -p $base_dir/db

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
ogr2ogr_bin=$(yq -r '.tool.gdal.ogr2ogr.path' $base_dir/tmp/sl-np-mapping.yaml)
spatialite_bin=$(yq -r '.tool.spatialite.path' $base_dir/tmp/sl-np-mapping.yaml)

#Download if map does not exists
if ! [ -f "$base_dir/var/$np-cleansed-merged.osm" ] || ! [ -f "$base_dir/var/$np-srtm.tiff" ] ; then
	echo "No OSM or elevation data. Please run 'init-data.sh' first"
    exit 1
fi

# gdal_contour does not have an overwrite option
rm $base_dir/db/$np.db

# Generate contours and insert them to the park's db. We have to do this before inserting geometries from the OSM file
# because gdal_contour does not support updating an existing DB but ogr2ogr does
# "$gdal_contour_bin" -a elev -i 10 -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -lco COMPRESS_GEOM=YES -nln contours $base_dir/var/$np-srtm.tiff $base_dir/db/$np.db

# then insert the geometries from the OSM file
"$ogr2ogr_bin" -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -lco COMPRESS_GEOM=YES $base_dir/db/$np.db $base_dir/var/$np-cleansed-merged.osm

# Add the contours
"$ogr2ogr_bin" -update -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -lco COMPRESS_GEOM=YES -nln sl_contour $base_dir/db/$np.db $base_dir/var/sl-contour.shp

# Insert the coastline
"$ogr2ogr_bin" -update -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -lco COMPRESS_GEOM=YES -nln sl_landmass $base_dir/db/$np.db $base_dir/var/sl-coastline.osm multipolygons

# Insert admin features
"$ogr2ogr_bin" -update -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -lco COMPRESS_GEOM=YES -nln sl_admin $base_dir/db/$np.db $base_dir/var/sl-admin.osm lines

# Refine and clean the data set
sed 's/{$np}/'$np'/g' $base_dir/script/enrich-and-add-geometry.sql > $base_dir/tmp/enrich-and-add-geometry.sql
"$spatialite_bin" $base_dir/db/$np.db < $base_dir/tmp/enrich-and-add-geometry.sql