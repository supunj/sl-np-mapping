from qgis.core import QgsApplication, QgsProject, QgsVectorLayer, QgsDataSourceUri, QgsFillSymbol, QgsLineSymbol, QgsSingleSymbolRenderer, QgsWkbTypes, QgsMarkerSymbol, QgsSvgMarkerSymbolLayer, QgsMarkerSymbol, QgsRasterLayer
import csv
import sys
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QColor
from pathlib import Path
# from qgis.analysis import QgsNativeAlgorithms

# Check if the database path and properties file path are provided
if len(sys.argv) < 4:
    print("Inadequate parameters.")
    sys.exit(1)

# Get the database path and properties file from command-line arguments
np = sys.argv[1]
db_path = sys.argv[2]
layers_file = sys.argv[3]
hill_shade_raster_file = sys.argv[4]
new_project_path = sys.argv[5]
symbol_path = sys.argv[6]

# Initialize QGIS Application in headless mode (for standalone scripts)
qgs = QgsApplication([], False)
qgs.initQgis()

# New QGIS project
project = QgsProject.instance()
project.writeEntry('Paths', 'Absolute', False)  # Set paths to relative
project.write(new_project_path)

# Set up the URI for the SpatiaLite layer with the SQL query
uri = QgsDataSourceUri()
uri.setDatabase(db_path)

# First add the raster layer with hill-shading so that it sits at the bottom
hill_shade_raster_layer = QgsRasterLayer(hill_shade_raster_file, "hill_shade")

# Check if the layer is valid
if hill_shade_raster_layer.isValid():
    # Add the raster layer to the current project
    project.addMapLayer(hill_shade_raster_layer)
    print("Raster layer added successfully.")
else:
    print("Failed to load the raster layer.")

# Open and read the CSV file
with open(layers_file, mode='r', newline='') as file:
    reader = csv.reader(file, delimiter='|')
    
    # Loop through each row in the CSV file
    for row in reader:
        print()  # Print the row, or perform other operations as needed
        uri.setDataSource("", row[1], "geom", row[2], "ogc_fid")

        # Create a new vector layer from the URI
        layer = QgsVectorLayer(uri.uri(), row[0], "spatialite")

        # Check if the layer is valid
        if layer.isValid():
            if layer.geometryType() == QgsWkbTypes.PolygonGeometry:
                symbol = QgsFillSymbol.createSimple({'color': row[3], 'outline_color': row[4], 'outline_width': row[5]})
                if float(row[5]) == 0: symbol.symbolLayer(0).setStrokeStyle(Qt.NoPen)
                #layer.setOpacity(0.85)
            elif layer.geometryType() == QgsWkbTypes.LineGeometry:
                symbol = QgsLineSymbol.createSimple({'color': row[3], 'width': row[5]})
            elif layer.geometryType() == QgsWkbTypes.PointGeometry:
                if Path(symbol_path + "/" + row[0] + ".svg").is_file():
                    # Create an SVG marker symbol layer
                    svg_symbol_layer = QgsSvgMarkerSymbolLayer(symbol_path + "/" + row[0] + ".svg")
                    svg_symbol_layer.setColor(QColor(row[3]))
                    svg_symbol_layer.setSize(float(row[5]))
                    svg_symbol_layer.setStrokeWidth(0.2)
                    svg_symbol_layer.setStrokeColor(QColor("#ffffff"))
                    svg_symbol_layer.setAngle(0)

                    # Create a marker symbol and add the SVG layer to it
                    symbol = QgsMarkerSymbol()
                    symbol.changeSymbolLayer(0, svg_symbol_layer)
                else:
                    symbol = QgsMarkerSymbol.createSimple({'name': 'circle', 'color': row[3], 'size': row[5]})                             
            
            layer.setRenderer(QgsSingleSymbolRenderer(symbol))
            # Set opacity
            layer.renderer().symbol().setOpacity(float(row[6]))

            # Add the layer to the new project
            project.addMapLayer(layer)
            print("Layer added to the new project.")
        else:
            print("Layer failed to load.")  

# ----This segment was used to invoke QGIS functions to do geometric manipulations. They were moved to Spatialite for flexibility. But keeping this segment in case it is needed in the future.----
# # Load the input SpatiaLite layers
# boundary = project.instance().mapLayersByName("boundary")[0]
# all_poly_sans_boundary = project.instance().mapLayersByName("all_poly_sans_boundary")[0]

# sys.path.append('/usr/share/qgis/python/plugins/')
# from qgis import processing
# from processing.core.Processing import Processing
# qgs.processingRegistry().addProvider(QgsNativeAlgorithms())

# difference_result = processing.run("qgis:difference", {
#     'INPUT':boundary.dataProvider().dataSourceUri(),
#     'OVERLAY':all_poly_sans_boundary.dataProvider().dataSourceUri(),
#     'OUTPUT':'spatialite://dbname=' + db_path + ' table="forest_cover_2" (geom)' ,'GRID_SIZE':None
# })

# # Load the resulting layer into the project
# forest_cover_layer = QgsVectorLayer('dbname=' + db_path + ' table="forest_cover_2" (geom)', "forest_cover_2", "spatialite")
# symbol = QgsFillSymbol.createSimple({'color': "#668B4E", 'outline_color': "transparent", 'outline_width': 0})
# symbol.symbolLayer(0).setStrokeStyle(Qt.NoPen)
# forest_cover_layer.setRenderer(QgsSingleSymbolRenderer(symbol))
# forest_cover_layer.setOpacity(0.85)
# project.addMapLayer(forest_cover_layer)
# #project.removeMapLayer(all_poly_sans_boundary)

# print("Difference layer created successfully.")
#...............................................................................................................................................................................................----

# Save the project to the specified path
project.write(new_project_path)
print(f"New QGIS project created and saved at: {new_project_path}")

# Clean up by closing the QGIS application
qgs.exitQgis()