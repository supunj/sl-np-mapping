#!/bin/sh

np=$1

echo $np

# Get the national park
$('pwd')/tools/osmosis-0.49.2/bin/osmosis \
            --read-xml file=$('pwd')/maps/$np.osm \
        	--tf accept-nodes \
        	--tf accept-ways \
        	--tf reject-ways boundary=administrative \
        	--tf accept-relations \
        	--tf reject-relations boundary=administrative \
            --used-node \
        	--bounding-polygon file=$('pwd')/poly/$np.poly \
        	--write-xml $('pwd')/output/$np-cleansed.osm