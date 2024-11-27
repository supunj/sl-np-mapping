-- Split the background at the coastline into ocean polygon and the terrain polygon
drop view if exists background_polygons;

create view background_polygons as
with background_split as (
    select 
        ST_Split(background.geom, coastline.geom) as background_collection
    from (select ST_Union(geom) as geom
		  from multipolygons
		  where name = '{$np}_background') as background,
        ( select ST_LineMerge(ST_Union(geom)) as geom
		  from lines
		  where INSTR(other_tags, '"natural"=>"coastline"')) as coastline
    where ST_Intersects(background.geom, coastline.geom)
)
select 
    ST_GeometryN(background_collection, 2) as terrain,
    ST_GeometryN(background_collection, 1) as ocean
from background_split
where ST_NumGeometries(background_collection) = 2;

insert into multipolygons(name, type, natural, other_tags, geom)
                select '{$np}_ocean', 'multipolygon', 'water', '"water"=>"ocean"', ST_Multi(ocean)
                from background_polygons;

insert into multipolygons(name, type, place, geom)
                select '{$np}_terrain', 'multipolygon', 'island', ST_Multi(terrain)
                from background_polygons;

-- Crop all ways to the background polygon
update lines
set geom = case
            when ST_GeometryType(ST_Intersection(lines.geom, polygons.geom)) = 'LINESTRING' then ST_Intersection(lines.geom, polygons.geom)
            when ST_GeometryType(ST_Intersection(lines.geom, polygons.geom)) = 'GEOMETRYCOLLECTION' then ST_GeometryN(ST_Intersection(lines.geom, polygons.geom), 1)
            else null
           end
from (
      select ST_Union(geom) as geom
      from multipolygons
      where name = '{$np}_background'
      ) as polygons;

-- Crop contours to the background polygon
update contours
set geom = case
               when ST_GeometryType(ST_Intersection(contours.geom, polygons.geom)) = 'LINESTRING' then ST_Intersection(contours.geom, polygons.geom)
               when ST_GeometryType(ST_Intersection(contours.geom, polygons.geom)) = 'GEOMETRYCOLLECTION' then ST_GeometryN(ST_Intersection(contours.geom, polygons.geom), 1)
               else null
           end
from (
      select ST_Union(multipolygons.geom) as geom
      from multipolygons
      where name = '{$np}_background'
     ) as polygons;

-- Remove the points outside of the background polygon
delete
from points
where not ST_Within(geom, (select ST_Union(multipolygons.geom) as geom
                           from multipolygons
                           where name = '{$np}_background'));

-- Tag contours
alter table contours add column type text;
update contours
set type = case
            when elev % 100 = 0 then 'major'
            when elev % 20 = 0 then 'medium'
            else 'minor'
           end;

-- Remove the original background polygon
delete from multipolygons where name = '{$np}_background';

-- Create a view with all feature polygons. This will be used to create the forest cover
drop table if exists feature_polygons;

create table feature_polygons (
  ogc_fid integer not null primary key autoincrement,
  name text null
);

select AddGeometryColumn('feature_polygons', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);

insert into feature_polygons
select ogc_fid, name, geom
from multipolygons
where boundary is not 'national_park' and 
      name is not '{$np}_terrain' and
      name is not '{$np}_ocean' and
	    ST_IsValid(geom);


-- Derive the forest cover
drop table if exists forest_cover;

create table forest_cover (
  ogc_fid integer not null primary key autoincrement,
  name text null
);

select AddGeometryColumn('forest_cover', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);

insert into forest_cover(name, geom)
select  case
          when ST_Difference(boundary.geom, other_poly.geom) is not null then 'forest_cover'
          else '{$np}_boundary_error'
        end as name,
        case
          when ST_Difference(boundary.geom, other_poly.geom) is not null then ST_Multi(ST_Difference(boundary.geom, other_poly.geom))
          else ST_Multi(ST_Buffer(ST_Centroid(other_poly.geom), 0.01))
        end as geom
from (
      select ST_Union(geom) as geom
      from multipolygons
      where boundary = 'national_park'
     ) as boundary,
     (
      select ST_Union(geom) as geom
      from feature_polygons
     ) as other_poly
where ST_Intersects(boundary.geom, other_poly.geom);

-- Remove and update the ocean polygons and the terrain after removing other polygons and the boundary
update multipolygons
set geom = ST_Multi(diff.geom)
from (with boundary_and_other_poly as (
      select ST_Union(geom) as geom
      from (select geom
            from feature_polygons
            union
            select geom
            from multipolygons
            where boundary is 'national_park')
    )
    select multipolygons.ogc_fid as ogc_fid,
           case
            when ST_Difference(multipolygons.geom, boundary_and_other_poly.geom) is not null then multipolygons.name
            else '{$np}_boundary_error'
           end as name,
           case
             when ST_Difference(multipolygons.geom, boundary_and_other_poly.geom) is not null then ST_Difference(multipolygons.geom, boundary_and_other_poly.geom)
             else ST_Buffer(ST_Centroid(multipolygons.geom), 0.1)
           end as geom
    from boundary_and_other_poly, multipolygons
    where (multipolygons.name is '{$np}_terrain' or
          multipolygons.name is '{$np}_ocean') and
          ST_Intersects(multipolygons.geom, boundary_and_other_poly.geom)) as diff
where multipolygons.name = diff.name;

-- For some reason man_made='clearcut' tagged polygons end up in lines table as closed lines. Make multipolygons from those and insert into polygons table. Then delete lines
insert into multipolygons(osm_id, osm_way_id, name, man_made, other_tags, geom)
select osm_id, osm_id, name, man_made, other_tags, ST_Multi(ST_MakePolygon(geom))
from lines
where man_made = 'clearcut' and ST_IsClosed(geom);

delete 
from lines
where man_made = 'clearcut';

-- Make contour lines more rounder (Visually pleasing)


-- Insert a point in the middle of culverts
insert into points(name, other_tags, geom) 
select name, other_tags,ST_PointN(ST_GeometryN(geom, 1), ST_NPoints(geom) / 2 + 1) AS midpoint
from lines
where waterway is not null and
      INSTR(other_tags, '"tunnel"=>"culvert"') > 0;

-- Insert points to each named multi-polygon
insert into points(name, geom) 
    select name,ST_Centroid(geom)
    from multipolygons
    where name is not NULL;