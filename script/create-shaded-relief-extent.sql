-- update {$np}_boundary_polygon
-- set geom = ST_Multi(ST_Buffer(ST_Centroid(geom), 0.1));

update {$np}_poly
set geom = ST_Multi(ST_Buffer(geom, ST_Perimeter(geom) * 0.001 / (2 * ST_Area(geom))));