#!/bin/sh

np=$1
scale=$2
format=$3
base_dir=$4

# Create the output folder if it does not exist
mkdir -p $base_dir/render/$np

# Config params to tmp
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml

python3_bin=$(yq -r '.tool.python.python3.path' $base_dir/tmp/sl-np-mapping.yaml)
output_file_name=$(yq -r '.park.'$np'.output_file_name' $base_dir/tmp/sl-np-mapping.yaml)

"$python3_bin" $base_dir/tool/generate-pdf-png-map.py \
                                                        $np \
                                                        $scale \
                                                        $format \
                                                        $base_dir/qgis/$np.qgz \
                                                        $base_dir/tmp/sl-np-mapping.yaml \
                                                        $base_dir/render/$np/"$output_file_name"_1_$scale.$format