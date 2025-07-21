#!/bin/sh
set -eu

np=$1

# Project root
base_dir=$2

rm $base_dir/tmp/$np-srtm-projected.tiff

gdalwarp \
         -t_srs EPSG:32644 \
         -tr 30 30 \
         -r bilinear \
         $base_dir/var/$np-srtm.tiff \
         $base_dir/tmp/$np-srtm-projected.tiff

D=600              # metres you choose
S=$(gdalinfo -json $base_dir/tmp/$np-srtm-projected.tiff | jq -r '.geoTransform[1] | fabs')
MAX_LENGTH=$(echo "$D / $S" | bc)
echo $MAX_LENGTH

whitebox_tools \
                -r=BreachDepressions \
                --dem=$base_dir/tmp/$np-srtm-projected.tiff \
                --max_length=$MAX_LENGTH \
                -o=$base_dir/tmp/$np-srtm-projected-breached.tiff

whitebox_tools \
                -r=FillDepressions \
                --dem=$base_dir/tmp/$np-srtm-projected-breached.tiff \
                -o=$base_dir/tmp/$np-srtm-projected-breached-filled.tiff

# D8 flow direction
whitebox_tools \
                -r=D8Pointer \
                --dem=$base_dir/tmp/$np-srtm-projected-breached-filled.tiff \
                -o=$base_dir/tmp/$np-srtm-projected-breached-filled-ponited.tiff

# D8 contributing area (# of upstream cells)
whitebox_tools \
                -r=D8FlowAccumulation \
                --dem=$base_dir/tmp/$np-srtm-projected-breached-filled.tiff \
                -o=$base_dir/tmp/$np-srtm-projected-breached-filled-accumulation.tiff

whitebox_tools \
                -r=ExtractStreams \
                --flow_accum=$base_dir/tmp/$np-srtm-projected-breached-filled-accumulation.tiff \
                --threshold=0.7 \
                -o=$base_dir/tmp/$np-srtm-projected-breached-filled-accumulation-stream.tiff # binary raster (1 = stream)

whitebox_tools \
                -r=RasterStreamsToVector \
                --streams=$base_dir/tmp/$np-srtm-projected-breached-filled-accumulation-stream.tiff \
                --d8_pntr=$base_dir/tmp/$np-srtm-projected-breached-filled-ponited.tiff \
                -o=$base_dir/var/$np-river-systems.shp