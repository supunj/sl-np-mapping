#!/bin/sh

np=$1

base_dir=$2

case "$np" in
    "lahugala") name="Lahugala Kitulana National Park";;
    "kumana") name="Kumana National Park";;
    "yb1") name="Yala National Park - Block 1";;
    *) break;;
esac

osmium tags-filter \
			-O \
			-o $base_dir/tmp/$np-boundary-polygon.osm \
			$base_dir/map/$np-cleansed.osm \
			"boundary=national_park" \
  			"n/name=$name" \
  			"r/type=boundary" \

osmium export --geometry-types=polygon $base_dir/tmp/$np-boundary-polygon.osm -O -o $base_dir/poly/$np-boundary-polygon.geojson
