#!/bin/sh

np=$1
scale=$2
base_dir=$3

# Config params to tmp
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml

python3_bin=$(yq -r '.tool.python.python3.path' $base_dir/tmp/sl-np-mapping.yaml)

"$python3_bin" $base_dir/tool/generate-qgis-layout.py \
                                                        $np \
                                                        $scale \
                                                        $base_dir