#!/bin/sh

polygon=$1 # .geojson

# Extract the extent line using grep and then process it with awk
extent_line=$(echo "$(ogrinfo -al -geom=NO $polygon)" | grep "Extent:")

if [ -n "$extent_line" ]; then
    set -- $(echo "$extent_line" | awk -F '[(), -]+' '{print $2, $3, $4, $5}')
    echo "$1|$2|$3|$4"
else
    echo "Extent not found."
fi
