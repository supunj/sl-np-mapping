from qgis.core import QgsApplication, QgsProject, QgsVectorLayer, QgsDataSourceUri, QgsFillSymbol, QgsLineSymbol, QgsSingleSymbolRenderer, QgsWkbTypes
import csv
import sys
from PyQt5.QtCore import Qt

# Check if the database path and properties file path are provided
if len(sys.argv) < 4:
    print("Inadequate parameters.")
    sys.exit(1)

# Get the database path and properties file from command-line arguments
np = sys.argv[1]
db_path = sys.argv[2]
layers_file = sys.argv[3]
new_project_path = sys.argv[4]

# Initialize QGIS Application in headless mode (for standalone scripts)
qgs = QgsApplication([], False)
qgs.initQgis()

# New QGIS project
project = QgsProject.instance()

# Set up the URI for the SpatiaLite layer with the SQL query
uri = QgsDataSourceUri()
uri.setDatabase(db_path)

# Open and read the CSV file
with open(layers_file, mode='r', newline='') as file:
    reader = csv.reader(file, delimiter='|')
    
    # Loop through each row in the CSV file
    for row in reader:
        print()  # Print the row, or perform other operations as needed
        uri.setDataSource("", row[1], "GEOMETRY", row[2], "ogc_fid")

        # Create a new vector layer from the URI
        layer = QgsVectorLayer(uri.uri(), row[0], "spatialite")

        # Check if the layer is valid
        if layer.isValid():
            if layer.geometryType() == QgsWkbTypes.PolygonGeometry:
                #symbol = QgsFillSymbol.createSimple({'color': 'blue', 'outline_color': 'white', 'outline_width': '0.0'})
                symbol = QgsFillSymbol.createSimple({'color': row[3], 'outline_color': row[4], 'outline_width': row[5]})
                #symbol.deleteSymbolLayer(1)
                #symbol.symbolLayer(0).setStrokeWidth(0.0)
                if float(row[5]) == 0: symbol.symbolLayer(0).setStrokeStyle(Qt.NoPen)
            elif layer.geometryType() == QgsWkbTypes.LineGeometry:
                symbol = QgsLineSymbol.createSimple({'color': row[4], 'width': row[5]})

            layer.setRenderer(QgsSingleSymbolRenderer(symbol))
            # Add the layer to the new project
            project.addMapLayer(layer)
            print("Layer added to the new project.")
        else:
            print("Layer failed to load.")

# Save the project to the specified path
project.write(new_project_path)
print(f"New QGIS project created and saved at: {new_project_path}")

# Clean up by closing the QGIS application
qgs.exitQgis()