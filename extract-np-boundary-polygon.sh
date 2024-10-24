#!/bin/sh

np=$1

echo $np

base_dir="$(dirname "$(readlink -f "$0")")"

osmium tags-filter \
			-O \
			-o $base_dir/tmp/$np-boundary-polygon.osm \
			$base_dir/map/$np-cleansed.osm \
			"boundary=national_park" \
  			"n/name=Lahugala Kitulana National Park" \
  			"r/type=boundary" \

osmium export --geometry-types=polygon $base_dir/tmp/$np-boundary-polygon.osm -O -o $base_dir/poly/$np-boundary-polygon.geojson
