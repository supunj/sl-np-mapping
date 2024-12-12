# Maps of Sri Lanka's National Parks

## Why?

This project exists due to few different reasons. My long term hobby of creating custom maps for my Garmin devices was probably the original motivation. My being a long time contributor to [OpenStreetMap](https://www.openstreetmap.org) was another. I was also looking for an excuse to learn a bit about GIS. Finally, I received a request to create a map for a small National Park in the Eastern Province. I created that map using OSM data and did the styling in [Inkscape](https://inkscape.org) but eventually ended up scripting about 70% of the process of generating a printable map from acquisition, cleansing, enrichment of data to the generation the [QGIS](https://qgis.org) project with vector and raster layers.

![alt text](image/qgis.png)

## Limitations

1. Only supports OSM data in v6 XML format of in PBF format
2. Park boundary should be a closed way tagged as ['boundary=national_park'](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dnational_park) - This can be changed but will require some re-factoring time.

## Pre-requisites

1. A Linux box. The commands here are for Debian but any other distro would do 
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
11. [svgo](https://github.com/svg/svgo)
    - `nvm (curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash)`
    - `node.js (nvm install v22.12.0)`
    - `npm install -g svgo`
12. [QGIS](https://www.qgis.org) - `sudo apt install qgis`

### Optional

1. [Inkscape](https://inkscape.org) - `sudo apt install inkscape`
2. [JOSM](https://josm.openstreetmap.de) with 'poly' plugin for creating [OSM Polygon Filters](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format) - `sudo apt install josm`
3. [qrencode](https://fukuchi.org/works/qrencode) - `sudo apt install qrencode`
4. [VSCodium](https://vscodium.com) or any other IDE
5. Monaco font

## Steps

1. Clone the repo
2. Give shell scripts the execution permission
   ```
   $ chmod +x ./script/init-*.sh
   $ chmod +x ./script/get-bbox-for-polygon.sh
   $ chmod +x ./script/render-park.sh
   $ chmod +x ./script/generate-qr.sh
   ```
3. Change the conf (cp ./conf/sl-np-mapping-template.yaml ./conf/sl-np-mapping.yaml)