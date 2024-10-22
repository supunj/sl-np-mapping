#!/bin/sh

np=$1
size=$2

# Project root
base_dir="$(dirname "$(readlink -f "$0")")"

# Clean-up the tmp
rm $base_dir/tmp/*

# inkscape to plain
inkscape --export-plain-svg=$base_dir/tmp/$np-$size-plain.svg $base_dir/inkscape/$np-$size-inkscape.svg

# svg optimise
svgo $base_dir/tmp/$np-$size-plain.svg -o $base_dir/render/$np-$size-plain-optimised.svg

# svg to pdf
inkscape $base_dir/render/$np-$size-plain-optimised.svg --export-dpi=600 --export-text-to-path --export-pdf=$base_dir/render/$np-$size-plain-optimised.pdf

# Convert to png to preserve the filter effects
rsvg-convert $base_dir/render/$np-$size-plain-optimised.svg -o $base_dir/render/$np-$size-plain-optimised.png