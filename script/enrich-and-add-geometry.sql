-- First drop all forest polygons from the main polygons because we will process them separately later on
delete
from multipolygons
where natural = 'wood';

delete
from surrounding_forests_raw
where type is null;

-- Split the background at the coastline into ocean polygon and the terrain polygon
drop view if exists background_polygons;

create view background_polygons as
with recursive background_split as (
      select 1 as idx,
             ST_Split(background.geom, coastline.geom) as geom_collection,
		 background.geom as background_geom,
		 coastline.geom as coastline_geom,
		 (case
			when coastline.geom is null and background.geom is not null then background.geom
			else ST_GeometryN(ST_Split(background.geom, coastline.geom), 1)
		 end) as geom,
	       ST_NumGeometries(ST_Split(background.geom, coastline.geom)) as total_geoms
      from (select ST_Union(geom) as geom
		from multipolygons
		where name = '{$np}_background') as background,
           (select ST_LineMerge(ST_Union(geom)) as geom
		from lines
		where INSTR(other_tags, '"natural"=>"coastline"')) as coastline
      where ST_Intersects(background.geom, coastline.geom)
	
	union all
	
	select idx + 1,
		 geom_collection,
		 background_geom,
		 coastline_geom,
		 (case
				when coastline_geom is null and background_geom is not null then background_geom
				else ST_GeometryN(geom_collection, idx + 1)
			 end) as geom,
             total_geoms
      from background_split
      where idx < total_geoms
)
select geom,
	 (case
	   when ST_Contains((select ST_Union(geom) from sl_landmass), ST_PointOnSurface(geom)) = 1 then 'terrain'
	   else 'ocean'
	 end) as type
from background_split;

insert into multipolygons(name, type, natural, place, other_tags, geom)
				  select (case
				            when type = 'terrain' then '{$np}_terrain'
				            else '{$np}_ocean'
				         end) as name,
				         'multipolygon' as type, 
				         (case
						 when type = 'terrain' then null
						 else 'water'
					   end) as natural,
                                 (case
						 when type = 'terrain' then 'island'
						 else null
					   end) as place,
					   (case
						 when type = 'terrain' then null
						 else '"water"=>"ocean"'
					   end) as other_tags,
					   ST_Multi(geom) as geom
				  from background_polygons
                          where geom is not null;

-- This table will hold the difference after cutting out the boundary
drop table if exists surrounding_forests_diff;

create table surrounding_forests_diff (
  ogc_fid integer not null primary key autoincrement,
  name text null
);

select AddGeometryColumn('surrounding_forests_diff', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);

insert into surrounding_forests_diff(name, geom)
                                    with boundary as (
                                          select ST_Union(geom) as geom_b
                                          from multipolygons
                                          where boundary = 'national_park'
                                    )
                                    select surrounding_forests_raw.name,
                                           ST_Multi(ST_CollectionExtract(case
                                                                              when ST_Difference(geom, boundary.geom_b) is not null then ST_Multi(ST_Difference(geom, boundary.geom_b))
                                                                              else ST_Multi(ST_Buffer(ST_Centroid(geom), 0.01))
                                                                         end,3)) as geom
                                    from surrounding_forests_raw, boundary;

with background as (
	select geom as geom_b
	from multipolygons 
	where name = '{$np}_background'
)
update surrounding_forests_diff
set geom = ST_Multi(ST_Intersection(geom, background.geom_b))
from background;

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
update sl_contour
set geom = case
               when ST_GeometryType(ST_Intersection(sl_contour.geom, polygons.geom)) = 'LINESTRING' then ST_Intersection(sl_contour.geom, polygons.geom)
               when ST_GeometryType(ST_Intersection(sl_contour.geom, polygons.geom)) = 'GEOMETRYCOLLECTION' then ST_GeometryN(ST_Intersection(sl_contour.geom, polygons.geom), 1)
               else null
           end
from (
      select ST_Union(multipolygons.geom) as geom
      from multipolygons
      where name = '{$np}_background'
     ) as polygons;

-- Crop admin boundaries to buffered background polygon so that they extend away from the map features
update sl_admin
set geom = case
               when ST_GeometryType(ST_Intersection(sl_admin.geom, polygons.geom)) = 'LINESTRING' then ST_Intersection(sl_admin.geom, polygons.geom)
               when ST_GeometryType(ST_Intersection(sl_admin.geom, polygons.geom)) = 'GEOMETRYCOLLECTION' then ST_GeometryN(ST_Intersection(sl_admin.geom, polygons.geom), 1)
               else null
           end
from (
      select ST_Multi(ST_Buffer(ST_Union(multipolygons.geom), ST_Perimeter(ST_Union(multipolygons.geom)) * 0.001 / (2 * ST_Area(geom)))) as geom
      from multipolygons
      where name = '{$np}_background'
     ) as polygons;

-- Remove the points outside of the background polygon
delete
from points
where not ST_Within(geom, (select ST_Union(multipolygons.geom) as geom
                           from multipolygons
                           where name = '{$np}_background'));

-- Classify contours
alter table sl_contour add column type text;
alter table sl_contour add column name text;
update sl_contour
set type = case
            when elev % 100 = 0 then 'major'
            when elev % 20 = 0 then 'medium'
            else 'minor'
           end,
    name = cast(cast(elev as int) as text);

-- Remove the original background polygon
delete 
from multipolygons 
where name = '{$np}_background';

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
      natural is not 'wood' and -- Need to drop natural=wood polygons as these would normally cover the park boundary in it's entirety
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

-- Insert points to each named multi-polygon
insert into points(name, geom) 
    select name,ST_Centroid(geom)
    from multipolygons
    where name is not NULL;

-- Insert a point in the middle of each culverts
insert into points(name, other_tags, geom)
select culverts.name, culverts.other_tags, ST_Intersection(culverts.geom, highways.geom) as intersection_point
from (select *
	from lines
	where waterway is not null and
            INSTR(other_tags, '"tunnel"=>"culvert"') > 0) as culverts,
	(select *
	 from lines
	 where highway is not null) as highways 
where ST_Intersects(culverts.geom, highways.geom) and
      GeometryType(ST_Intersection(culverts.geom, highways.geom)) = 'POINT';

-- Insert a point in the middle of each bridges so that we can have a separate points layer for bridges
insert into points(other_tags, geom)
select bridges.other_tags, ST_Intersection(bridges.geom, waterways.geom) as intersection_point
from (select *
	from lines
	where highway is not null and
            INSTR(other_tags, '"bridge"=>') > 0) as bridges,
     (select *
	from lines
	where waterway is not null) as waterways	 
where ST_Intersects(bridges.geom, waterways.geom) and
      GeometryType(ST_Intersection(bridges.geom, waterways.geom)) = 'POINT';

-- Transform 'waterway = dam' into a polygon so that they would show up in the dam layer
insert into multipolygons(osm_id, name, type, other_tags, geom)
select osm_id, name, 'multipolygon', other_tags || ',"waterway"=>"' || waterway || '"', ST_Multi(ST_Buffer(geom, 0.00001))
from lines
where waterway in ('dam', 'weir');