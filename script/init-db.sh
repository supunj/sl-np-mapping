
#!/bin/sh

np=$1

# Project root
base_dir=$2

echo "--------------------------------> $np"
echo "--------------------------------> $base_dir"

#Download if map does not exists
if ! [ -f "$base_dir/var/$np-cleansed-merged.osm" ] || ! [ -f "$base_dir/var/$np-srtm.tiff" ] ; then
	echo "No OSM or elevation data. Please run 'init-park.sh' first"
    exit 1
fi

# gdal_contour does not have an overwrite option
rm $base_dir/db/$np.db

# Generate contours and insert them to the park's db. We have to do this before inserting geometries from the OSM file
# because gdal_contour does not support updating an existing DB but ogr2ogr does
gdal_contour -a elev -i 10 -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -nln contours $base_dir/var/$np-srtm.tiff $base_dir/db/$np.db

# then insert the geometries from the OSM file
ogr2ogr -update -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom $base_dir/db/$np.db $base_dir/var/$np-cleansed-merged.osm

# Extract the coastline and insert into SpatiaLite for later use
$base_dir/tool/osmosis-0.49.2/bin/osmosis \
			--read-pbf file=$base_dir/var/sri-lanka-latest.osm.pbf \
			--tf accept-ways natural=coastline \
			--tf accept-relations place=island \
			--bounding-polygon file=$base_dir/poly/sri-lanka.poly \
			--used-node \
			--write-xml $base_dir/tmp/sl-coastline.osm
            
ogr2ogr -update -f SQLite -dsco SPATIALITE=YES -lco GEOMETRY_NAME=geom -nln sl $base_dir/db/$np.db $base_dir/tmp/sl-coastline.osm multipolygons

# Refine and clean the data set
sed 's/{$np}/'$np'/g' $base_dir/script/enrich-and-add-geometry.sql > $base_dir/tmp/enrich-and-add-geometry.sql
spatialite $base_dir/db/$np.db < $base_dir/tmp/enrich-and-add-geometry.sql