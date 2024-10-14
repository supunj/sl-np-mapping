#!/bin/sh

np=$1
size=$2

# inkscape to plain
inkscape --export-plain-svg=$('pwd')/svg/$np-$size-plain.svg $('pwd')/svg/$np-$size-inkscape.svg

# svg optimise
svgo $('pwd')/svg/$np-$size-plain.svg -o $('pwd')/svg/$np-$size-plain-optimised.svg

# svg to pdf
inkscape $('pwd')/svg/$np-$size-plain-optimised.svg --export-dpi=600 --export-text-to-path --export-pdf=$('pwd')/pdf/$np-$size-plain-optimised.pdf