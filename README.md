# Sri Lankan National Park Maps

Pre-requisites

1. yq - sudo apt install yq
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