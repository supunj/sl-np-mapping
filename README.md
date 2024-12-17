# Maps of Sri Lanka's National Parks

## Why?

This project exists due to few different reasons. Long term hobby of creating custom maps for my Garmin devices was probably the original motivation. Being a long time contributor to [OpenStreetMap](https://www.openstreetmap.org) was another. There was also a need to find an excuse to learn a bit about GIS. Finally, receiving a request to create a map for a small National Park in the Eastern Province ticked off the check-list. That map was created using OSM data and the styling was done in [Inkscape](https://inkscape.org), but eventually ended up scripting about 70% of the process of generating a printable map from acquisition, cleansing and enrichment of data to the generation of the [QGIS](https://qgis.org) project with vector and raster layers.

![alt text](image/qgis.png)

Whatever is here can be used without any restrictions but attributions will be appreciated :pray:

## Limitations

1. Only supports OSM data in v6 XML format or in PBF format
2. Park boundary should be a closed way tagged as ['boundary=national_park'](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dnational_park) - This can be changed but will require some refactoring time.
3. The boundary should contain a unique name
4. Elevation data are in USGS SRTM format

## Pre-requisites

1. A Linux box. The commands here are for Debian but any other distro would do as long as you can get the dependencies running
2. [yq](https://github.com/mikefarah/yq) - `sudo apt install yq`
3. [poly2geojson](https://github.com/pirxpilot/poly2geojson)
    - `sudo apt install cargo`
    - `cargo install poly2geojson`
4. [osmosis](https://github.com/openstreetmap/osmosis/releases/latest) - `sudo apt install openjdk-21-jdk`
5. [GDAL](https://gdal.org/en/stable) - `sudo apt install gdal-bin`
6. [osmium](https://osmcode.org/osmium-tool) - `sudo apt install osmium-tool`
7. [SpatiaLite](https://www.gaia-gis.it/fossil/libspatialite/index) - `sudo apt install spatialite-bin`
8. [ImageMagick](https://imagemagick.org/script/index.php) - `sudo apt install imagemagick`
9. [rsvg-convert](https://github.com/bvibber/librsvg) - `sudo apt install librsvg2-bin`
10. [xmlstarlet](https://xmlstar.sourceforge.net) - `sudo apt install xmlstarlet`
11. [svgo](https://github.com/svg/svgo) - `npm install -g svgo`
    - *nvm - `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash`*
    - *node.js - `nvm install v22.12.0`*
12. [QGIS](https://www.qgis.org) - `sudo apt install qgis`

### Optional

1. [Inkscape](https://inkscape.org) - `sudo apt install inkscape`
2. [JOSM](https://josm.openstreetmap.de) with 'poly' plugin for creating [OSM Polygon Filters](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format) - `sudo apt install josm`
3. [qrencode](https://fukuchi.org/works/qrencode) - `sudo apt install qrencode`
4. [VSCodium](https://vscodium.com) or any other IDE
5. Monaco font

## Process

```mermaid
    %%{init: {'theme':'forest'}}%%
        flowchart TD
            start@{ shape: circle, label: "Start" }
            create_conf@{ shape: trap-t, label: "Create conf" }
            conf_yaml@{ shape: doc, label: ".yaml" }
            osm_mapping@{ shape: trap-t, label: "Add/Modify park in OSM" }
            park_poly_create@{ shape: trap-t, label: "Draw park polygon" }
            park_poly@{ shape: doc, label: ".poly" }
            osm_db@{ shape: cyl, label: "OSM" }
            osm_download@{ shape: rect, label: "Download \n OSM Data" }
            osm_data@{ shape: doc, label: ".pbf/.osm" }
            extract_park_data@{ shape: rect, label: "Extract park Data" }
            filtered_osm_data@{ shape: docs, label: "Filtered data (.osm)" }
            elevation_data@{ shape: docs, label: "Elevation data \n (.hgt/.tiff)" }
            gen_contour_lines@{ shape: rect, label: "Generate contour \n lines" }
            update_db@{ shape: rect, label: "Consolidate data and \n Update DB" }
            spatialite@{ shape: cyl, label: "SpatiaLite" }
            refine_data@{ shape: rect, label: "Refine data" }
            define_cmap_for_hill_shade@{ shape: trap-t, label: "Define colour map \n for shaded relief" }
            cmap_for_hill_shade@{ shape: doc, label: "Colour map (-cmap.txt)" }
            generate_shaded_relief@{ shape: rect, label: "Generate shaded relief" }
            hill_shade_raster@{ shape: doc, label: "Hill-shade (.tiff)" }
            define_qgis_layers@{ shape: trap-t, label: "Define QGIS layers" }
            qgis_layer_definitions@{ shape: doc, label: "Layers (.csv)" }
            create_map_symbols@{ shape: trap-t, label: "Create SVG \n map symbols" }
            map_symbols@{ shape: docs, label: ".svg" }
            generate_qgis_project@{ shape: rect, label: "Generate QGIS project" }
            refine_qgis_project@{ shape: trap-t, label: "Refine the map" }
            final_map@{ shape: doc, label: "Final map (.pdf/.svg/.png)" }
            stop@{ shape: dbl-circ, label: "Stop" }
            
            start --> create_conf
            create_conf --> conf_yaml
            create_conf --> park_poly_create
            park_poly_create --> park_poly
            park_poly_create --> osm_mapping            
            osm_mapping --> osm_db
            osm_mapping --> osm_download
            osm_download --> osm_data
            osm_download --> dependencies{Dependencies fulfilled?}
            dependencies --> |Yes| extract_park_data
            dependencies --> |No| start
            extract_park_data --> filtered_osm_data
            extract_park_data --> gen_contour_lines
            gen_contour_lines --> update_db
            elevation_data --> gen_contour_lines
            update_db --> spatialite
            update_db --> refine_data
            spatialite --> refine_data
            refine_data --> spatialite
            refine_data --> define_cmap_for_hill_shade
            define_cmap_for_hill_shade --> cmap_for_hill_shade
            define_cmap_for_hill_shade --> generate_shaded_relief
            elevation_data --> generate_shaded_relief
            generate_shaded_relief --> hill_shade_raster
            generate_shaded_relief --> define_qgis_layers
            define_qgis_layers --> qgis_layer_definitions            
            define_qgis_layers --> create_map_symbols
            create_map_symbols --> map_symbols
            create_map_symbols --> generate_qgis_project            
            generate_qgis_project --> refine_qgis_project
            refine_qgis_project --> final_map
            refine_qgis_project --> stop
   ```

## Steps

1. Clone the repo
2. Give shell scripts the execution permission
   ```
   $ chmod +x ./script/init-*.sh
   $ chmod +x ./script/get-bbox-for-polygon.sh
   $ chmod +x ./script/render-park.sh
   $ chmod +x ./script/generate-qr.sh
   ```
3. Create the config - `cp ./conf/sl-np-mapping-template.yaml ./conf/sl-np-mapping.yaml`
   You can use `{$HOME}` and `{$base_dir}` can be used and variables in the config and they will be replaced by the environment variables `$HOME` and `$base_dir` respectively. The configurable items are self descriptive.
4. Create the park polygon in JOSM and save it as a .poly file. The name of the file is quite important as you need to pass that to subsequent scripts.

   ![alt text](image/park_polygon.png)

   Make sure to change the second line, which is the polygon name to the park name. Typically the original value there would be `1`.

5. `./script/init-data.sh <park_name> $(pwd)` - Acquire and filter OSM data for the given parkThis produces following outputs.
   - `$base_dir/var/sri-lanka-latest.osm.pbf`
   - `$base_dir/var/sri-lanka.geojson`
   - `$base_dir/var/$np.geojson`
   - `$base_dir/var/$np-boundary-polygon.geojson`
   - `$base_dir/var/sl-coastline.osm`
   - `$base_dir/var/sl-admin.osm`
   - `$base_dir/var/$np-cleansed-merged.osm`
   - `$base_dir/var/$np-srtm.tiff`

6. `./script/init-db.sh yb1 $(pwd)` - Insert all the data collected to a SpatiaLite DB. SpatiaLite makes it possible to store the data without having to host a database server and also provides decent support for spatial data handling. This produces the file `$base_dir/db/$np.db`. During this process the vector data will be cleansed, massaged and enriched even more. 

7. Define the [colour map](https://gdal.org/en/stable/programs/gdaldem.html) for the shaded relief for the park and place it in `$base_dir\dem`. The park name should be prefixed.

8. `./script/init-shaded-relief.sh yb1 $(pwd)` - This generates the hill-shade background raster in GeoTIFF format with some effects for eye-candy.

    ![alt text](image/hill_shade_raster.png)

9. Define QGIS layers along with desired symbology. This is done in the file `$base_dir/qgis/layer/$np-qgis-layers.csv`. Below is the format of the CSV.

    |Layer Name|Table|Query (Where clause)|Fill Colour|Stroke Colour|Size(Stroke or Symbol)|Opacity|
    |---|---|---|---|---|---|---|
    |terrain|multipolygons|name = '{$np}_terrain' and place = 'island'|#aec3b0|transparent|0.0|0|
    minor_contour|contours|type = 'minor'|#f2e9e4|transparent|0.125|1
    river|lines|waterway = 'river'|#007ea7|transparent|1.5|1
    track|lines|highway = 'track'|#5e503f|transparent|0.5|1
    bungalow|points|"INSTR(other_tags, '""tourism""=>""chalet""') > 0"|#c8553d||8|1
    junction|points|"INSTR(other_tags, '""junction""=>""yes""') > 0"|#9d4edd||8|1
    locality|points|place = 'locality'|#233d4d||6|1

10. Create SVG symbols for POIs in the folder `$base_dir/symbol`. These will be converted to QGIS friendly SVG format in the next step and be placed in the folder `$base_dir/qgis/symbol/$np` for each park. If you use 3rd party SVGs, please make sure to make appropriate attributions. The file name should be as same as the respective QGIS layer name in the CSV file.

11. `./script/init-qgis-project.sh yb1 $(pwd)` - This will put everything together and generate a QGIS project that you can start working on

    ![alt text](image/qgis_project.png)

12. `./script/init-park.sh yb1 $(pwd)` - This will run all the above scripts all at once.