#!/bin/sh

np=$1

# Project root
base_dir=$2

echo "--------------------------------> $np"
echo "--------------------------------> $base_dir"

#Download if map does not exists
if ! [ -f "$base_dir/db/$np.db" ]; then
	echo "No SpatiaLite layers. Please run 'init-db.sh' first"
    exit 1
fi

# Generate QGIS project
sed 's/{$np}/'$np'/g' $base_dir/qgis/layer/$np-qgis-layers.csv > $base_dir/tmp/$np-qgis-layers.csv
python3 $base_dir/script/init-qgis-project.py $np $base_dir/db/$np.db $base_dir/tmp/$np-qgis-layers.csv $base_dir/var/$np-srtm-combined-transparent-geo-referenced-cropped.tiff $base_dir/qgis/$np.qgz $base_dir/symbol