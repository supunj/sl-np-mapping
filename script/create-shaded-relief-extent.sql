update {$np}_boundary_polygon
set geom = ST_Multi(ST_Buffer(ST_Centroid(geom), 0.1));