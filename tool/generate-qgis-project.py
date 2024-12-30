from qgis.core import (
    QgsApplication,
    QgsProject,
    QgsVectorLayer,
    QgsDataSourceUri,
    QgsFillSymbol,
    QgsLineSymbol,
    QgsSingleSymbolRenderer,
    QgsWkbTypes,
    QgsMarkerSymbol,
    QgsSvgMarkerSymbolLayer,
    QgsMarkerSymbol,
    QgsRasterLayer,
    QgsTextFormat,
    QgsTextBufferSettings,
    QgsPalLayerSettings,
    QgsVectorLayerSimpleLabeling,
    QgsSimpleLineSymbolLayer,
    QgsCoordinateReferenceSystem,
    QgsContrastEnhancement,
    QgsMultiBandColorRenderer,
    QgsTextBackgroundSettings
)
import csv
import sys
from PyQt5.QtCore import Qt, QSizeF
from PyQt5.QtGui import QColor, QFont
from pathlib import Path
# from qgis.analysis import QgsNativeAlgorithms

def setLabel(row, layer):
    # Add the label only if the font size is not 0
    if float(row[8]) != 0.0:
        # Set up text format
        text_format = QgsTextFormat()
        text_format.setFont(QFont(row[7]))
        text_format.setSize(float(row[8]))
        text_format.setColor(QColor(row[9]))

        # Add text buffer
        buffer_settings = QgsTextBufferSettings()
        buffer_settings.setColor(QColor("white"))
        buffer_settings.setSize(0.4)
        
        # Configure text background
        background_settings = QgsTextBackgroundSettings()        
        background_settings.setFillColor(QColor(row[9]))  # Set the background color
        background_settings.setStrokeColor(QColor("transparent"))  # No borders
        background_settings.setStrokeWidth(0)  # No borders
        background_settings.setType(QgsTextBackgroundSettings.ShapeRectangle)  # Set shape to rectangle
        background_settings.setSizeType(QgsTextBackgroundSettings.SizeBuffer)
        background_settings.setSize(QSizeF(0.5, 0.5))  # Add padding to the width
        background_settings.setRadii(QSizeF(1.0, 1.0))  # Radius for rounded corners
                
        label_settings = QgsPalLayerSettings()

        if layer.geometryType() == QgsWkbTypes.PolygonGeometry:
            label_settings.showAllLabels = True
            label_settings.placement = QgsPalLayerSettings.AroundPoint
            buffer_settings.setEnabled(False)            
            # Override the label settings defined in the layers file
            text_format.setColor(QColor("black"))
            background_settings.setFillColor(QColor("white"))
            background_settings.setOpacity(0.6)
            background_settings.setEnabled(True)
        elif layer.geometryType() == QgsWkbTypes.LineGeometry:
            label_settings.placement = QgsPalLayerSettings.Curved
            buffer_settings.setEnabled(True)
            background_settings.setEnabled(False)
        elif layer.geometryType() == QgsWkbTypes.PointGeometry:
            label_settings.showAllLabels = True
            label_settings.placement = QgsPalLayerSettings.OrderedPositionsAroundPoint
            label_settings.dist = 5
            buffer_settings.setEnabled(False)
            background_settings.setEnabled(True)
            
            # Override the font colour based on the stroke colour
            if row[4] == "" or row[4] == "transparent":
                text_format.setColor(QColor("white"))
            else:
                text_format.setColor(QColor("black"))
                
        # Set the settings to the text format parent        
        text_format.setBuffer(buffer_settings)
        text_format.setBackground(background_settings)

         # Set up label settings        
        label_settings.fieldName = "name"
        label_settings.setFormat(text_format)
        label_settings.MinScale = 0  # Minimum scale (0 for unlimited)
        label_settings.MaxScale = 1e10  # Maximum scale (large number for unlimited)

        # Set the labeling layer to the vector layer
        labeling_layer = QgsVectorLayerSimpleLabeling(label_settings)
        layer.setLabelsEnabled(True)
        layer.setLabeling(labeling_layer)

def setLayerContrastEnhancement(layer):
    renderer = layer.renderer()
    if isinstance(renderer, QgsMultiBandColorRenderer):
        for band in [1, 2, 3]: # We know its only 3 bands for now
            contrast_enhancement = QgsContrastEnhancement(renderer.dataType(band))
            # Turn off the contrast enhancement for each band
            contrast_enhancement.setContrastEnhancementAlgorithm(QgsContrastEnhancement.NoEnhancement)
            if band == 1:
                renderer.setRedContrastEnhancement(contrast_enhancement)
            elif band == 2:
                renderer.setGreenContrastEnhancement(contrast_enhancement)
            elif band == 3:
                renderer.setBlueContrastEnhancement(contrast_enhancement)
    else:
        print("Single band - to be implemented when needed.")
        
def getSVGSymbolLayer(symbol_path, row):
    svg_symbol_layer = QgsSvgMarkerSymbolLayer(symbol_path)
    svg_symbol_layer.setColor(QColor(row[3]))
    svg_symbol_layer.setSize(float(row[5]))
    
    if row[4] == "" or row[4] == "transparent":
        svg_symbol_layer.setStrokeWidth(float(0.0))
    else:
        svg_symbol_layer.setStrokeWidth(float(0.25))
        
    svg_symbol_layer.setStrokeColor(QColor(row[4]))
    svg_symbol_layer.setAngle(0)
    return svg_symbol_layer

def main():
    # Check if the database path and properties file path are provided
    if len(sys.argv) < 4:
        print("Inadequate parameters.")
        sys.exit(1)

    # Get the database path and properties file from command-line arguments
    np = sys.argv[1]
    db_path = sys.argv[2]
    layers_file = sys.argv[3]
    hill_shade_raster_file = sys.argv[4]
    park_outer_glow_raster_file = sys.argv[5]
    new_project_path = sys.argv[6]
    symbol_path = sys.argv[7]
    coordinate_reference_system = sys.argv[8]

    # Initialize QGIS Application in headless mode (for standalone scripts)
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # New QGIS project
    project = QgsProject.instance()
    crs = QgsCoordinateReferenceSystem(coordinate_reference_system)
    project.setCrs(crs)
    project.writeEntry("Paths", "Absolute", False)  # Set paths to relative
    project.write(new_project_path)

    # Set up the URI for the SpatiaLite layer with the SQL query
    uri = QgsDataSourceUri()
    uri.setDatabase(db_path)

    # First add the raster layer with park glow so that it sits at the bottom
    park_outer_glow_raster_layer = QgsRasterLayer(
        park_outer_glow_raster_file, "park_outer_glow"
    )

    # Check if the layer is valid
    if park_outer_glow_raster_layer.isValid():
        # Switch off the contrast enhancement
        setLayerContrastEnhancement(park_outer_glow_raster_layer)
        # Add the raster layer to the current project
        project.addMapLayer(park_outer_glow_raster_layer)
        print("Park glow layer added successfully.")
    else:
        print("Failed to load the raster layer.")

    # Then add the raster layer with hill-shading
    hill_shade_raster_layer = QgsRasterLayer(hill_shade_raster_file, "hill_shade")

    # Check if the layer is valid
    if hill_shade_raster_layer.isValid():
        # Switch off the contrast enhancement
        setLayerContrastEnhancement(hill_shade_raster_layer)
        # Add the raster layer to the current project
        project.addMapLayer(hill_shade_raster_layer)
        print("Hill-shade layer added successfully.")
    else:
        print("Failed to load the raster layer.")

    with open(layers_file, mode="r", newline="") as file:
        reader = csv.reader(file, delimiter="|")

        for row in reader:
            uri.setDataSource("", row[1], "geom", row[2], "ogc_fid")

            # Create a new vector layer from the URI
            layer = QgsVectorLayer(uri.uri(), row[0], "spatialite")

            # Check if the layer is valid
            if layer.isValid():
                if layer.geometryType() == QgsWkbTypes.PolygonGeometry:
                    symbol = QgsFillSymbol.createSimple(
                        {
                            "color": row[3],
                            "outline_color": row[4],
                            "outline_width": row[5],
                        }
                    )
                    if float(row[5]) == 0:
                        symbol.symbolLayer(0).setStrokeStyle(Qt.NoPen)
                elif layer.geometryType() == QgsWkbTypes.LineGeometry:
                    symbol = QgsLineSymbol.createSimple(
                        {"color": row[4], "width": float(row[5]) * 1.5, "capstyle": "round"}
                    )
                    inner_line = QgsSimpleLineSymbolLayer()
                    inner_line.setColor(QColor(row[3]))
                    inner_line.setWidth(float(row[5]))
                    inner_line.setPenCapStyle(Qt.RoundCap) # Set round end caps for lines
                    symbol.appendSymbolLayer(inner_line)
                elif layer.geometryType() == QgsWkbTypes.PointGeometry:
                    if Path(symbol_path + "/" + row[0] + ".svg").is_file():
                        symbol = QgsMarkerSymbol()
                        symbol.changeSymbolLayer(0, getSVGSymbolLayer(symbol_path + "/" + row[0] + ".svg", row))
                    else:
                        symbol = QgsMarkerSymbol.createSimple(
                            {"name": "circle", "color": row[3], "size": row[5]}
                        )

                layer.setRenderer(QgsSingleSymbolRenderer(symbol))
                layer.renderer().symbol().setOpacity(float(row[6]))

                setLabel(row, layer)

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
    # ...............................................................................................................................................................................................----

    # Save the project to the specified path
    project.write(new_project_path)
    print(f"New QGIS project created and saved at: {new_project_path}")

    # Clean up by closing the QGIS application
    qgs.exitQgis()

if __name__ == "__main__":
    main()
