# Maps of Sri Lanka's National Parks

## Why?

This project exists due to few reasons. My long term hobby of creating custom maps for my Garmin devices was probably the original motivation. My being a long time contributor to [OpenStreetMap](https://www.openstreetmap.org) was another. I was also looking for an excuse to learn a bit about GIS. Finally, I received a request to create a map for a small National Park in the Eastern Province. I created that map using OSM data and did the styling in [Inkscape](https://inkscape.org) but eventually ended up scripting about 70% of the process of generating a printable map from acquisition, cleansing, enrichment of data to the generation the [QGIS](https://qgis.org) project with vector and raster layers.

![alt text](image/qgis.png)

## Limitations

1. Only supports OSM data in v6 XML format of in PBF format
2. Park boundary should be a closed way tagged as ['boundary=national_park'](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dnational_park) - This can be changed but will require some re-factoring time.

## Pre-requisites

0. A Linux box. The commands here are for Debian but any other distro would do 
1. yq
    - sudo apt install yq
2. poly2geojson
    - sudo apt install cargo
    - cargo install poly2geojson
3. osmosis - https://github.com/openstreetmap/osmosis/releases/latest
    - sudo apt install openjdk-21-jdk
4. GDAL - https://gdal.org/en/stable
    - sudo apt install gdal-bin
5. osmium - https://osmcode.org/osmium-tool/
    - sudo apt install osmium-tool
6. SpatiaLite - https://www.gaia-gis.it/fossil/libspatialite/index
    - sudo apt install spatialite-bin
7. ImageMagick - https://imagemagick.org/script/index.php
    - sudo apt install imagemagick
8. rsvg-convert
    - sudo apt install librsvg2-bin
9. xmlstarlet
    - sudo apt install xmlstarlet
10. svgo - https://github.com/svg/svgo
    - nvm (curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash)
    - node.js (nvm install v22.12.0)
    - npm install -g svgo
11. QGIS - https://www.qgis.org
    - sudo apt install qgis

Optional

1. Inkscape (https://inkscape.org)
    - sudo apt install inkscape
2. JOSM (https://josm.openstreetmap.de)
    - sudo apt install josm
3. qrencode
    - sudo apt install qrencode
4. VSCodium (https://vscodium.com)

Fonts

1. Monaco

Steps

1. chmod +x ./script/init-*.sh
2. chmod +x ./script/get-bbox-for-polygon.sh
3. chmod +x ./script/render-park.sh
4. chmod +x ./script/generate-qr.sh
5. Change the conf (cp ./conf/sl-np-mapping-template.yaml ./conf/sl-np-mapping.yaml)