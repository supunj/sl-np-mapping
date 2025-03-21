#!/bin/sh
set -eu

np=$1
format=$2
base_dir=$3

mkdir -p $base_dir/render/$np

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
python3_bin=$(yq -r '.tool.python.python3.path' $base_dir/tmp/sl-np-mapping.yaml)
output_file_name=$(yq -r '.park.'$np'.output_file_name' $base_dir/tmp/sl-np-mapping.yaml)
svgo_bin=$(yq -r '.tool.svgo.path' $base_dir/tmp/sl-np-mapping.yaml)

# This can't be run unless data and db is not available
if ! [ -f "$base_dir/db/$np.db" ]; then
	echo "No SpatiaLite layers. Please run 'init-db.sh' first"
    exit 1
fi

"$python3_bin" $base_dir/tool/generate-qgis-overview-map.py \
                                                            $np \
                                                            $base_dir/tmp/sl-np-mapping.yaml \
                                                            $base_dir/db/$np.db \
                                                            $base_dir/qgis/"$np"_overview.qgz \
                                                            $base_dir/tmp/"$output_file_name"_Overview_Raw.$format \
                                                            $format

if [ format = "svg" ]; then
    # Optimise the svg
    "$svgo_bin" \
                --config=$base_dir/conf/svgo.config.js \
                --input $base_dir/tmp/"$output_file_name"_Overview_Raw.svg \
                --output $base_dir/render/$np/"$output_file_name"_Overview.svg
else
    mv $base_dir/tmp/"$output_file_name"_Overview_Raw.$format $base_dir/render/$np/"$output_file_name"_Overview.$format
fi