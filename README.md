# Maps of Sri Lanka's National Parks

## Why?

This project exists due to few different reasons. My long term hobby of creating custom maps for my Garmin devices was probably the original motivation. My being a long time contributor to [OpenStreetMap](https://www.openstreetmap.org) was another. I was also looking for an excuse to learn a bit about GIS. Finally, receiving a request to create a map for a small National Park in the Eastern Province completed the check-list. I created that map using OSM data and did the styling in [Inkscape](https://inkscape.org) but eventually ended up scripting about 70% of the process of generating a printable map from acquisition, cleansing, enrichment of data to the generation the [QGIS](https://qgis.org) project with vector and raster layers.

![alt text](image/qgis.png)

Whatever is here can be used without any restrictions but attributions will be appreciated :pray:

## Limitations

1. Only supports OSM data in v6 XML format or in PBF format
2. Park boundary should be a closed way tagged as ['boundary=national_park'](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dnational_park) - This can be changed but will require some re-factoring time.
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
    - [Optional] nvm - `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash`
    - [Optional] node.js - `nvm install v22.12.0`
12. [QGIS](https://www.qgis.org) - `sudo apt install qgis`

### Optional

1. [Inkscape](https://inkscape.org) - `sudo apt install inkscape`
2. [JOSM](https://josm.openstreetmap.de) with 'poly' plugin for creating [OSM Polygon Filters](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format) - `sudo apt install josm`
3. [qrencode](https://fukuchi.org/works/qrencode) - `sudo apt install qrencode`
4. [VSCodium](https://vscodium.com) or any other IDE
5. Monaco font

## Process

```mermaid
        flowchart TD
            start@{ shape: circle, label: "Start" }
            conf_data@{ shape: manual-input, label: "Config" }
            create_conf@{ shape: rect, label: "Create conf" }
            conf_yaml@{ shape: doc, label: ".yaml" }
            park_data@{ shape: manual-input, label: "Geo-spatial data" }
            osm_mapping@{ shape: rect, label: "Add/Modify park in OSM" }
            josm@{ shape: manual-input, label: "Polygon data" }
            park_poly_create@{ shape: rect, label: "Draw park polygon" }
            park_poly@{ shape: doc, label: ".poly" }
            osm_db@{ shape: cyl, label: "OSM" }
            osm_download@{ shape: rect, label: "Download \n OSM Data" }
            osm_data@{ shape: doc, label: ".pbf/.osm" }
            extract_park_data@{ shape: rect, label: "Extract park Data" }
            filtered_osm_data@{ shape: docs, label: "Filtered data (.osm)" }
            elevation_data@{ shape: doc, label: "Elevation data \n (.hgt/.tiff)" }
            gen_contour_lines@{ shape: rect, label: "Generate contour \n lines" }
            update_db@{ shape: rect, label: "Update DB" }
            spatialite@{ shape: cyl, label: "SpatiaLite" }
            refine_data@{ shape: rect, label: "Refine data" }
            generate_shaded_relief@{ shape: rect, label: "Generate shaded relief" }
            hill_shade_raster@{ shape: doc, label: "Hill-shade (.tiff)" }
            qgis_layers@{ shape: manual-input, label: "QGIS Layers" }
            define_qgis_layers@{ shape: rect, label: "Define QGIS layers" }
            qgis_layer_definitions@{ shape: doc, label: "Layers (.csv)" }
            generate_qgis_project@{ shape: rect, label: "Generate QGIS project" }
            refine_qgis_project@{ shape: rect, label: "Refine the map" }
            final_map@{ shape: doc, label: "Final map (.pdf/.svg/.png)" }
            stop@{ shape: dbl-circ, label: "Stop" }
            
            start --> create_conf
            conf_data --> create_conf
            create_conf --> conf_yaml
            start --> osm_mapping
            park_data --> osm_mapping
            start --> park_poly_create
            josm --> park_poly_create
            park_poly_create --> park_poly
            osm_mapping --> osm_db
            osm_db --> osm_download
            osm_download --> osm_data
            create_conf --> dependencies{Dependencies fulfilled?}
            park_poly_create --> dependencies{Dependencies fulfilled?}
            osm_download --> dependencies{Dependencies fulfilled?}
            dependencies --> |Yes| extract_park_data
            dependencies --> |Yes| generate_shaded_relief
            dependencies --> |No| start
            %%{conf_yaml --> extract_park_data}%%
            %%{park_poly --> extract_park_data}%%
            %%{osm_data --> extract_park_data}%%
            extract_park_data --> filtered_osm_data
            generate_shaded_relief --> hill_shade_raster
            extract_park_data --> gen_contour_lines
            elevation_data --> gen_contour_lines
            %%{conf_yaml --> gen_contour_lines}%%
            %%{park_poly --> gen_contour_lines}%%
            filtered_osm_data --> update_db
            gen_contour_lines --> spatialite
            update_db --> spatialite
            spatialite --> refine_data
            refine_data --> spatialite
            refine_data --> define_qgis_layers
            qgis_layers --> define_qgis_layers
            define_qgis_layers --> qgis_layer_definitions
            qgis_layer_definitions --> generate_qgis_project
            hill_shade_raster --> generate_qgis_project
            generate_qgis_project --> refine_qgis_project
            refine_qgis_project --> final_map
            final_map --> stop
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
3. Change the conf - `cp ./conf/sl-np-mapping-template.yaml ./conf/sl-np-mapping.yaml`
4. TBC

   