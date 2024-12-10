#!/bin/sh

np=$1
size=$2

# Project root
base_dir=$3

# Create runtime folders if they don't exist
mkdir -p $base_dir/tmp
mkdir -p $base_dir/var

# Config params
sed -e 's|{\$HOME}|'$(printf '%s' "$HOME" | sed 's|/|\\/|g')'|g' \
    -e 's|{\$base_dir}|'$(printf '%s' "$base_dir" | sed 's|/|\\/|g')'|g' $base_dir/conf/sl-np-mapping.yaml > $base_dir/tmp/sl-np-mapping.yaml
rsvg_convert_bin=$(yq -r '.tool.rsvg_convert.path' $base_dir/tmp/sl-np-mapping.yaml)
svgo_bin=$(yq -r '.tool.svgo.path' $base_dir/tmp/sl-np-mapping.yaml)
inkscape_bin=$(yq -r '.tool.inkscape.path' $base_dir/tmp/sl-np-mapping.yaml)

# inkscape to plain
"$inkscape_bin" --export-plain-svg=$base_dir/tmp/$np-$size-plain.svg $base_dir/inkscape/$np-$size-inkscape.svg

# svg optimise
"$svgo_bin" $base_dir/tmp/$np-$size-plain.svg -o $base_dir/render/$np-$size-plain-optimised.svg

# svg to pdf
"$inkscape_bin" $base_dir/render/$np-$size-plain-optimised.svg --export-dpi=600 --export-text-to-path --export-pdf=$base_dir/render/$np-$size-plain-optimised.pdf

# Convert to png to preserve the filter effects
"$rsvg_convert_bin" $base_dir/render/$np-$size-plain-optimised.svg -o $base_dir/render/$np-$size-plain-optimised.png