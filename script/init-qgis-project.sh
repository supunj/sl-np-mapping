#!/bin/sh

np=$1

# Project root
base_dir=$2

# Create the background polygon from the .poly file
python3 $base_dir/script/poly-to-osm.py $np $base_dir/poly/$np.poly $base_dir/tmp/$np-background.osm

# Merge OSM data, contours and the background polygon
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
            --read-xml file=$base_dir/map/$np-cleansed.osm \
            --read-xml file=$base_dir/map/$np-contours-cleansed.osm \
			--read-xml file=$base_dir/tmp/$np-background.osm \
			--sort \
        	--merge \
			--merge \
        	--bounding-polygon file=$base_dir/poly/$np.poly completeWays=yes \
        	--write-xml $base_dir/tmp/$np-cleansed-merged.osm

# Polulate spatialite
rm $base_dir/db/$np.db
ogr2ogr -f "SQLite" -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom $base_dir/db/$np.db $base_dir/tmp/$np-cleansed-merged.osm

sed 's/{$np}/'$np'/g' $base_dir/script/enrich-and-add-geometry.sql > $base_dir/tmp/enrich-and-add-geometry.sql
spatialite $base_dir/db/$np.db < $base_dir/tmp/enrich-and-add-geometry.sql

# Generate QGIS project
sed 's/{$np}/'$np'/g' $base_dir/qgis/layer/$np-qgis-layers.csv > $base_dir/tmp/$np-qgis-layers.csv
python3 $base_dir/script/init-qgis-project.py $np $base_dir/db/$np.db $base_dir/tmp/$np-qgis-layers.csv $base_dir/qgis/$np.qgz