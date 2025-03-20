-- First drop all forest and protected area polygons from the main polygons because we will process them separately later on
delete
from multipolygons
where natural = 'wood' or landuse = 'forest';

delete
from multipolygons
where boundary = 'protected_area';

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
            from background) as background,
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

drop table if exists background_multipolygons;

create table background_multipolygons (
  ogc_fid integer not null primary key autoincrement,
  name text null,
  type text null,
  natural text null,
  place text null,
  other_tags text null
);
select AddGeometryColumn('background_multipolygons', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);
select CreateSpatialIndex('background_multipolygons', 'geom');

insert into background_multipolygons(name, type, natural, place, other_tags, geom)
				  select (case
				            when type = 'terrain' then '{$np}_terrain'
				            else 'Indian Ocean'
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

-- Surrounding forests - this table will hold the difference after cutting out the boundary
drop table if exists surrounding_forests_diff;

create table surrounding_forests_diff (
  ogc_fid integer not null primary key autoincrement,
  name text null,
  other_tags text null
);
select AddGeometryColumn('surrounding_forests_diff', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);
select CreateSpatialIndex('surrounding_forests_diff', 'geom');

insert into surrounding_forests_diff(name, other_tags, geom)                                    
                                    select surrounding_forests_raw.name,
                                           surrounding_forests_raw.other_tags,
                                           ST_Multi(ST_CollectionExtract(ST_Multi(ST_Difference(geom, boundary.geom_b)), 3)) as geom
                                    from surrounding_forests_raw,
                                         (select ST_Union(geom) as geom_b
                                          from park_boundary) as boundary
                                    where ST_Difference(geom, boundary.geom_b) is not null;

update surrounding_forests_diff
set geom = ST_Multi(ST_Intersection(surrounding_forests_diff.geom, background.geom))
from (select ST_Union(geom) as geom
      from background) as background;

-- Surrounding protected areas - this table will hold the difference after cutting out the boundary
drop table if exists surrounding_protected_areas_diff;

create table surrounding_protected_areas_diff (
  ogc_fid integer not null primary key autoincrement,
  name text null,
  other_tags text null
);
select AddGeometryColumn('surrounding_protected_areas_diff', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);
select CreateSpatialIndex('surrounding_protected_areas_diff', 'geom');

insert into surrounding_protected_areas_diff(name, other_tags, geom)
                                                select surrounding_protected_areas_raw.name,
                                                       surrounding_protected_areas_raw.other_tags,
                                                       ST_Multi(ST_CollectionExtract(ST_Multi(ST_Difference(geom, boundary.geom_b)), 3)) as geom
                                                from surrounding_protected_areas_raw, 
                                                     (select ST_Union(geom) as geom_b
                                                      from park_boundary) as boundary
                                                where ST_Difference(geom, boundary.geom_b) is not null;

update surrounding_protected_areas_diff
set geom = ST_Multi(ST_Intersection(surrounding_protected_areas_diff.geom, background.geom))
from (select ST_Union(geom) as geom
      from background) as background;

-- We don't need entire polygons...instead we insert a POI on the surface of the polygon 
insert into points(name, other_tags, geom)
select name,
	 case
		when INSTR(other_tags, '"maritime"=>"yes"') > 0 then ifnull(other_tags, '') || ',"protected_area"=>"marine"'
		else ifnull(other_tags, '') || ',"protected_area"=>"terrestrial"'
	 end,
	 ST_StartPoint(GEOSMaximumInscribedCircle(geom, 0)) as visual_center
from surrounding_protected_areas_diff
where name is not null;

-- Crop all polygons to the background polygon
create table cropped_multipolygons as select multipolygons.*, cast(ST_AsText(ST_Transform(ST_Intersection(multipolygons.geom, background.geom), 4326)) as text) as geom_tmp
                              from multipolygons,
                                   (select ST_Union(geom) as geom
                                    from background) as background
                              where ST_Intersects(multipolygons.geom, background.geom);
-- TODO : This will only handle polygon and multipolygons. We need to find an easier way to handle geometrycollections.
delete 
from cropped_multipolygons 
where GeometryType(ST_GeomFromText(geom_tmp)) in ('GEOMETRYCOLLECTION');

alter table cropped_multipolygons drop column geom;
select AddGeometryColumn('cropped_multipolygons', 'geom',  4326, 'MULTIPOLYGON', 'XY', 0);
select CreateSpatialIndex('cropped_multipolygons', 'geom');
update cropped_multipolygons
      set geom = ST_Multi(ST_GeomFromText(geom_tmp, 4326))
where GeometryType(ST_GeomFromText(geom_tmp)) in ('POLYGON', 'MULTIPOLYGON');

alter table cropped_multipolygons drop column geom_tmp;

-- update cropped_multipolygons
-- 		set geom = with recursive split_geometries as (
-- 						select ogc_fid,
-- 							   geom_tmp,
-- 							   1 as idx,
-- 							   GeometryN(ST_GeomFromText(geom_tmp), 1) as extracted_geometry
-- 						from cropped_multipolygons
-- 						where GeometryType(ST_GeomFromText(geom_tmp)) = 'GEOMETRYCOLLECTION'
						
-- 						union all
						
-- 						select s.ogc_fid,
-- 							   s.geom_tmp,
-- 							   s.idx + 1,
-- 							   GeometryN(ST_GeomFromText(s.geom_tmp), s.idx + 1)
-- 						from split_geometries s
-- 						where s.idx + 1 <= NumGeometries(s.geom_tmp)
-- 					)
-- 					select ST_Union(extracted_geometry)
-- 					from split_geometries
-- 					where GeometryType(extracted_geometry) in ('POLYGON', 'MULTIPOLYGON');

-- Crop all ways to the background polygon
create table cropped_lines as select lines.*, cast(ST_AsText(ST_Transform(ST_Intersection(lines.geom, background.geom), 4326)) as text) as geom_tmp
                              from lines,
                                   (select ST_Union(geom) as geom
                                    from background) as background
                              where ST_Intersects(lines.geom, background.geom);
alter table cropped_lines drop column geom;
select AddGeometryColumn('cropped_lines', 'geom',  4326, 'MULTILINESTRING', 'XY', 0);
select CreateSpatialIndex('cropped_lines', 'geom');
update cropped_lines 
      set geom = ST_Multi(ST_GeomFromText(geom_tmp, 4326));
alter table cropped_lines drop column geom_tmp;

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

-- Crop contours to the background polygon
create table cropped_sl_contour as select sl_contour.*, 
                                          cast(ST_AsText(ST_Transform(ST_Intersection(sl_contour.geom, background.geom), 4326)) as text) as geom_tmp
                                   from sl_contour,
                                        (select ST_Union(geom) as geom
                                         from background) as background
                                   where ST_Intersects(sl_contour.geom, background.geom);
alter table cropped_sl_contour drop column geom;
select AddGeometryColumn('cropped_sl_contour', 'geom',  4326, 'MULTILINESTRING', 'XY', 0);
select CreateSpatialIndex('cropped_sl_contour', 'geom');
update cropped_sl_contour 
      set geom = ST_Multi(ST_GeomFromText(geom_tmp, 4326));
alter table cropped_sl_contour drop column geom_tmp;

-- Crop admin boundaries to buffered background polygon so that they extend away from the map features. After that delete the lines with null geometries.
update sl_admin
set geom = case
               when ST_GeometryType(ST_Intersection(sl_admin.geom, buffered_background.geom)) = 'LINESTRING' then ST_Intersection(sl_admin.geom, buffered_background.geom)
               when ST_GeometryType(ST_Intersection(sl_admin.geom, buffered_background.geom)) = 'GEOMETRYCOLLECTION' then ST_GeometryN(ST_Intersection(sl_admin.geom, buffered_background.geom), 1)
               else null
           end
from (
      select ST_Multi(ST_Buffer(ST_Union(geom), ST_Perimeter(ST_Union(geom)) * 0.001 / (2 * ST_Area(geom)))) as geom
      from background
     ) as buffered_background;

delete
from sl_admin
where geom is null;

-- Remove the points outside of the background polygon
delete
from points
where not ST_Within(geom, (select ST_Union(geom) as geom
                           from background));

-- Create a table with all feature polygons. This will be used to create the forest cover
drop table if exists feature_polygons;

create table feature_polygons (
  ogc_fid integer not null primary key autoincrement,
  name text null
);
select AddGeometryColumn('feature_polygons', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);
select CreateSpatialIndex('feature_polygons', 'geom');

insert into feature_polygons
select ogc_fid, name, geom
from cropped_multipolygons
where ST_IsValid(geom);

-- Derive the forest cover
drop table if exists forest_cover;

create table forest_cover (
  ogc_fid integer not null primary key autoincrement,
  name text null
);
select AddGeometryColumn('forest_cover', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);
select CreateSpatialIndex('forest_cover', 'geom');

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
      from park_boundary
     ) as boundary,
     (
      select ST_Union(geom) as geom
      from feature_polygons
     ) as other_poly
where ST_Intersects(boundary.geom, other_poly.geom);

-- Remove and update the ocean polygons and the terrain after removing other polygons and the boundary
update background_multipolygons
set geom = ST_Multi(diff.geom)
from (with boundary_and_other_poly as (
      select ST_Union(geom) as geom
      from (select geom
            from feature_polygons
            union
            select geom
            from park_boundary
            union
            select geom
            from surrounding_forests_diff
            union
            select geom
            from surrounding_protected_areas_diff
            where INSTR(other_tags, '"maritime"=>"yes"') <= 0 
            )
    )
    select background_multipolygons.ogc_fid as ogc_fid,
           case
            when ST_Difference(background_multipolygons.geom, boundary_and_other_poly.geom) is not null then background_multipolygons.name
            else '{$np}_boundary_error'
           end as name,
           case
             when ST_Difference(background_multipolygons.geom, boundary_and_other_poly.geom) is not null then ST_Difference(background_multipolygons.geom, boundary_and_other_poly.geom)
             else ST_Buffer(ST_Centroid(background_multipolygons.geom), 0.1)
           end as geom
    from boundary_and_other_poly, background_multipolygons
    where (background_multipolygons.name is '{$np}_terrain' or
          background_multipolygons.name is 'Indian Ocean') and
          ST_Intersects(background_multipolygons.geom, boundary_and_other_poly.geom)) as diff
where background_multipolygons.name = diff.name;

-- For some reason man_made='clearcut' tagged polygons end up in lines table as closed lines. Make multipolygons from those and insert into polygons table. Then delete lines
insert into cropped_multipolygons(osm_id, osm_way_id, name, man_made, other_tags, geom)
select osm_id, osm_id, name, man_made, other_tags, ST_Multi(ST_MakePolygon(geom))
from cropped_lines
where man_made = 'clearcut' and ST_IsClosed(geom);

delete
from cropped_lines
where man_made = 'clearcut';

-- Insert points to each named multi-polygon
-- insert into points(name, geom) 
--     select name,ST_Centroid(geom)
--     from multipolygons
--     where name is not NULL;

-- Insert a point in the middle of each culverts
insert into points(name, other_tags, geom)
select culverts.name, culverts.other_tags, ST_Intersection(culverts.geom, highways.geom) as intersection_point
from (select *
	from cropped_lines
	where waterway is not null and
            INSTR(other_tags, '"tunnel"=>"culvert"') > 0) as culverts,
	(select *
	 from cropped_lines
	 where highway is not null) as highways 
where ST_Intersects(culverts.geom, highways.geom) and
      GeometryType(ST_Intersection(culverts.geom, highways.geom)) = 'POINT';

-- Insert a point in the middle of each bridges so that we can have a separate points layer for bridges
insert into points(name, other_tags, geom)
select case
		when bridges.name like '% Bridge%' then bridges.name
		else ''
	 end,
       bridges.other_tags,
       ST_Intersection(bridges.geom, waterways.geom) as intersection_point
from (select *
	from cropped_lines
	where highway is not null and
            INSTR(other_tags, '"bridge"=>') > 0) as bridges,
     (select *
	from cropped_lines
	where waterway is not null) as waterways	 
where ST_Intersects(bridges.geom, waterways.geom) and
      GeometryType(ST_Intersection(bridges.geom, waterways.geom)) = 'POINT';

-- Transform 'waterway = dam' into a polygon so that they would show up in the dam layer
insert into cropped_multipolygons(osm_id, name, type, other_tags, geom)
select osm_id, name, 'multipolygon', other_tags || ',"waterway"=>"' || waterway || '"', ST_Multi(ST_Buffer(geom, 0.00001))
from cropped_lines
where waterway in ('dam', 'weir');

-- Create a rectangle that represent the desired park canvas. This will be used in QGIS layout to calculate map extend.
create table park_canvas (
  ogc_fid integer not null primary key autoincrement,
  name text null
);
select AddGeometryColumn('park_canvas', 'geom',  4326, 'MULTIPOLYGON', 'XY', 1);
select CreateSpatialIndex('park_canvas', 'geom');

insert into park_canvas(ogc_fid, name, geom)
select 1 as ogc_fid,
	 'Park Canvas' as name,
	 ST_Multi(Envelope(Buffer(geom, 0))) as geom
from background;