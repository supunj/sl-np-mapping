#!/bin/sh

np=$1

# Project root
base_dir=$2

# Download, extract and prepare the park data 
$base_dir/script/init-data.sh $np $base_dir

# Create the SpatiaLite db
$base_dir/script/init-db.sh $np $base_dir

# Generate hill-shading
$base_dir/script/init-shaded-relief.sh $np $base_dir

# Generate the QGIS project
$base_dir/script/init-qgis-project.sh $np $base_dir