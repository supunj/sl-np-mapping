#!/bin/sh

np=$1
echo $np

osmium extract \
			--polygon $('pwd')/poly/$np.poly \
			--strategy simple \
			--clean uid --clean user --clean changeset \
			-O \
			-o $('pwd')/output/$np-contours.osm \
			$('pwd')/maps/sl-contours.osm.pbf

$('pwd')/tools/osmosis-0.49.2/bin/osmosis \
            --read-xml file=$('pwd')/output/$np-contours.osm \
  			--tag-filter reject-relations \
			--tag-filter accept-ways \
			--used-node \
			--write-xml $('pwd')/output/$np-contours-cleansed.osm