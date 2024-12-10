#!/bin/sh

np=$1

# Project root
base_dir=$2

symbol_dir=$base_dir/qgis/symbol/$np

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
rsvg_convert_bin=$(yq -r '.tool.rsvg_convert.path' $base_dir/tmp/sl-np-mapping.yaml)
xmlstarlet_bin=$(yq -r '.tool.xmlstarlet.path' $base_dir/tmp/sl-np-mapping.yaml)
svgo_bin=$(yq -r '.tool.svgo.path' $base_dir/tmp/sl-np-mapping.yaml)
python3_bin=$(yq -r '.tool.python.python3.path' $base_dir/tmp/sl-np-mapping.yaml)

# This can't be run unless data and db is not available
if ! [ -f "$base_dir/db/$np.db" ]; then
	echo "No SpatiaLite layers. Please run 'init-db.sh' first"
    exit 1
fi

# Generate QGIS project
sed 's/{$np}/'$np'/g' $base_dir/qgis/layer/$np-qgis-layers.csv > $base_dir/tmp/$np-qgis-layers.csv

if ! [ -f "$symbol_dir" ]; then
	mkdir -p $symbol_dir
else
    rm $symbol_dir/*
fi

# Read the CSV file
while IFS='|' read layer_name column2; do

    if [ -f "$base_dir/symbol/$np-$layer_name.svg" ]; then
        svg=$base_dir/symbol/$np-$layer_name.svg
    elif [ -f "$base_dir/symbol/$layer_name.svg" ]; then
        svg=$base_dir/symbol/$layer_name.svg
    else
        continue;
    fi

    # Re-size the svg - source svg needs to have the same width and the height
    "$rsvg_convert_bin" $svg -w 580 -h 580 -f svg -o $base_dir/tmp/$layer_name.svg

    # Add QGIS related parameters to the svg so that the colours can be changed
    "$xmlstarlet_bin" ed -N ns="http://www.w3.org/2000/svg" \
                -u "//ns:path/@fill" -v "param(fill)" \
                -u "//ns:path/@fill-opacity" -v "param(fill-opacity)" \
                -u "//ns:path/@stroke" -v "param(outline)" \
                -u "//ns:path/@stroke-opacity" -v "param(outline-opacity)" \
                -u "//ns:path/@stroke-width" -v "param(outline-width)" \
                -i "//ns:path[not(@fill)]" -t attr -n "fill" -v "param(fill)" \
                -i "//ns:path[not(@fill-opacity)]" -t attr -n "fill-opacity" -v "param(fill-opacity)" \
                -i "//ns:path[not(@stroke)]" -t attr -n "stroke" -v "param(outline)" \
                -i "//ns:path[not(@stroke-opacity)]" -t attr -n "stroke-opacity" -v "param(outline-opacity)" \
                -i "//ns:path[not(@stroke-width)]" -t attr -n "stroke-width" -v "param(outline-width)" \
                $base_dir/tmp/$layer_name.svg > $base_dir/tmp/$layer_name-attr-add.svg

    # Optimise the svg
    "$svgo_bin" --config=$base_dir/conf/svgo.config.js --input $base_dir/tmp/$layer_name-attr-add.svg --output $symbol_dir/$layer_name.svg

done < "$base_dir/tmp/$np-qgis-layers.csv"

"$python3_bin" $base_dir/tool/generate-qgis-project.py $np $base_dir/db/$np.db $base_dir/tmp/$np-qgis-layers.csv $base_dir/var/$np-srtm-combined-cropped-halo-geo-referenced.tiff $base_dir/qgis/$np.qgz $base_dir/qgis/symbol/$np