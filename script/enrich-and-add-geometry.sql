insert into points(name, GEOMETRY) 
    select name,ST_Centroid(geometry)
    from multipolygons
    where name is not NULL;