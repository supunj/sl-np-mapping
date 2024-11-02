#!/bin/sh

np=$1

# Project root
base_dir=$2

# Merge OSM data and the contours
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
            --read-xml file=$base_dir/map/$np-cleansed.osm \
            --read-xml file=$base_dir/map/$np-contours-cleansed.osm \
        	--merge \
        	--bounding-polygon file=$base_dir/poly/$np.poly completeWays=yes \
        	--write-xml $base_dir/tmp/$np-cleansed-merged.osm

# Polulate spatialite
ogr2ogr -f "SQLite" -dsco SPATIALITE=YES $base_dir/db/$np.db $base_dir/tmp/$np-cleansed-merged.osm

# Generate QGIS project
python3 $base_dir/script/generate-qgis-project.py $np $base_dir/db/$np.db $base_dir/script/qgis-layers.csv $base_dir/qgis/$np.qgz