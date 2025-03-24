import csv
from pathlib import Path
import sys
from ruamel.yaml import YAML
from ruamel.yaml.parser import ParserError
from typing import Any, Dict
from PyQt5.QtCore import QSizeF, Qt
from PyQt5.QtGui import QColor, QFont, QPainter
from qgis.core import (
    Qgis,
    QgsApplication,
    QgsContrastEnhancement,
    QgsCoordinateReferenceSystem,
    QgsDataSourceUri,
    QgsFillSymbol,
    QgsLineSymbol,
    QgsMarkerLineSymbolLayer,
    QgsMarkerSymbol,
    QgsMarkerSymbol,
    QgsMultiBandColorRenderer,
    QgsPalLayerSettings,
    QgsProject,
    QgsProperty,
    QgsRasterLayer,
    QgsSVGFillSymbolLayer,
    QgsSimpleLineSymbolLayer,
    QgsSimpleMarkerSymbolLayer,
    QgsSingleSymbolRenderer,
    QgsSvgMarkerSymbolLayer,
    QgsSymbolLayer,
    QgsTextBackgroundSettings,
    QgsTextBufferSettings,
    QgsTextFormat,
    QgsVectorLayer,
    QgsVectorLayerSimpleLabeling,
    QgsLabelObstacleSettings,
    QgsLabelLineSettings,
)

# from qgis.analysis import QgsNativeAlgorithms


yaml = YAML(typ="safe")

# Type alias for configuration
ConfigDict = Dict[str, Any]


def loadConfig(config_path: str) -> ConfigDict:
    try:
        return yaml.load(Path(config_path))
    except FileNotFoundError:
        raise SystemExit(f"🚨 Config file not found: {config_path}")
    except ParserError as e:
        raise SystemExit(f"🔴 YAML syntax error: {e}")
    except Exception as e:
        raise SystemExit(f"⚡ Unexpected error loading config: {e}")


def setLabel(row, layer, print_scale):
    # Add the label only if the font size is not 0
    if float(row[8]) != 0.0:
        # Set up text format
        text_format = QgsTextFormat()
        text_format.setFont(QFont(row[7]))
        text_format.setSize(float(row[8]))
        text_format.setColor(QColor(row[9]))

        # Add text buffer
        buffer_settings = QgsTextBufferSettings()
        buffer_settings.setColor(QColor("#ffffff"))
        buffer_settings.setSize(0.4)
        buffer_settings.setEnabled(False)  # Disable buffer by default

        # Configure text background
        background_settings = QgsTextBackgroundSettings()
        background_settings.setFillColor(
            QColor(row[3])
        )  # Set the default background color
        background_settings.setStrokeColor(QColor("transparent"))  # No borders
        background_settings.setStrokeWidth(0)  # No borders
        background_settings.setType(
            QgsTextBackgroundSettings.ShapeType.ShapeRectangle
        )  # Set shape to rectangle
        background_settings.setSizeType(QgsTextBackgroundSettings.SizeType.SizeBuffer)
        background_settings.setSize(QSizeF(0.5, 0.5))  # Add padding
        background_settings.setRadii(QSizeF(1.0, 1.0))  # Radius for rounded corners
        background_settings.setEnabled(False)  # Disable background by default

        label_settings = QgsPalLayerSettings()
        label_settings.dataDefinedProperties().setProperty(
            QgsPalLayerSettings.Property.Size,
            QgsProperty.fromExpression(
                f"""
                calculate_size(@map_scale, {row[8]}, {print_scale})
                """
            ),
        )

        obstacle_settings = QgsLabelObstacleSettings()
        obstacle_settings.setIsObstacle(False)
        obstacle_settings.setFactor(0.0)
        label_settings.setObstacleSettings(obstacle_settings)

        if layer.geometryType() == Qgis.GeometryType.Polygon:
            label_settings.displayAll = True
            label_settings.placement = Qgis.LabelPlacement.AroundPoint
            polygon_label_placement_flags = Qgis.LabelPolygonPlacementFlags(
                Qgis.LabelPolygonPlacementFlag.AllowPlacementOutsideOfPolygon
                | Qgis.LabelPolygonPlacementFlag.AllowPlacementInsideOfPolygon
            )
            label_settings.setPolygonPlacementFlags(polygon_label_placement_flags)
            label_settings.centroidWhole = False
            label_settings.centroidInside = True
            label_settings.dist = 0
            label_settings.distUnits = Qgis.RenderUnit.Millimeters

            buffer_settings.setEnabled(False)

            background_settings.setFillColor(QColor("#ffffff"))
            background_settings.setOpacity(0.6)
            background_settings.setEnabled(True)
        elif layer.geometryType() == Qgis.GeometryType.Line:
            label_settings.placement = Qgis.LabelPlacement.Curved
            line_label_settings = QgsLabelLineSettings()
            line_label_placement_flags = Qgis.LabelLinePlacementFlags(
                Qgis.LabelLinePlacementFlag.OnLine
                | Qgis.LabelLinePlacementFlag.AboveLine
                | Qgis.LabelLinePlacementFlag.BelowLine
                | Qgis.LabelLinePlacementFlag.MapOrientation
            )
            line_label_settings.setPlacementFlags(line_label_placement_flags)
            label_settings.setLineSettings(line_label_settings)
            buffer_settings.setEnabled(True)
        elif layer.geometryType() == Qgis.GeometryType.Point:
            label_settings.displayAll = True
            label_settings.placement = Qgis.LabelPlacement.OrderedPositionsAroundPoint
            label_settings.dist = 5
            buffer_settings.setEnabled(False)

            if row[10] == "yes+":  # Enable background for the label as well
                # text_format.setColor(QColor("#eeeeee"))
                background_settings.setEnabled(True)
                buffer_settings.setEnabled(False)  # Disable buffer for the label

        # Set the settings to the text format parent
        text_format.setBuffer(buffer_settings)
        text_format.setBackground(background_settings)

        # Set up label settings
        label_settings.fieldName = "name"
        label_settings.setFormat(text_format)
        label_settings.minimumScale = 0  # 0 for unlimited
        label_settings.maximumScale = 1e10  # large number for unlimited

        # Set the labeling layer to the vector layer
        labeling_layer = QgsVectorLayerSimpleLabeling(label_settings)
        layer.setLabelsEnabled(True)
        layer.setLabeling(labeling_layer)


def setLayerContrastEnhancement(layer):
    renderer = layer.renderer()
    if isinstance(renderer, QgsMultiBandColorRenderer):
        for band in [1, 2, 3]:  # We know its only 3 bands for now
            contrast_enhancement = QgsContrastEnhancement(renderer.dataType(band))
            # Turn off the contrast enhancement for each band
            contrast_enhancement.setContrastEnhancementAlgorithm(
                QgsContrastEnhancement.ContrastEnhancementAlgorithm.NoEnhancement
            )
            if band == 1:
                renderer.setRedContrastEnhancement(contrast_enhancement)
            elif band == 2:
                renderer.setGreenContrastEnhancement(contrast_enhancement)
            elif band == 3:
                renderer.setBlueContrastEnhancement(contrast_enhancement)
    else:
        print("Single band - to be implemented when needed.")


def createSVGPOISymbolLayer(symbol_path, row, print_scale):
    svg_symbol_layer = QgsSvgMarkerSymbolLayer(symbol_path)
    svg_symbol_layer.setColor(QColor(row[3]))
    svg_symbol_layer.setSize(float(row[5]))

    if row[4] == "" or row[4] == "transparent":
        svg_symbol_layer.setStrokeWidth(float(0.0))
    else:
        svg_symbol_layer.setStrokeWidth(float(0.25))

    svg_symbol_layer.setStrokeColor(QColor(row[4]))
    svg_symbol_layer.setAngle(0)
    svg_symbol_layer.setDataDefinedProperty(
        QgsSymbolLayer.Property.PropertySize,
        QgsProperty.fromExpression(
            f"""
            calculate_size(@map_scale, {row[5]}, {print_scale})
            """
        ),
    )
    return svg_symbol_layer


def createSVGBackgroundSymbolLayer(symbol_path, row, print_scale):
    svg_symbol_layer = QgsSvgMarkerSymbolLayer(symbol_path)
    svg_symbol_layer.setColor(QColor(row[9]))
    svg_symbol_layer.setSize(float(row[5]))
    svg_symbol_layer.setStrokeWidth(float(0.0))
    svg_symbol_layer.setDataDefinedProperty(
        QgsSymbolLayer.Property.PropertySize,
        QgsProperty.fromExpression(
            f"""
            calculate_size(@map_scale, {row[5]}, {print_scale})
            """
        ),
    )
    return svg_symbol_layer


def createSVGFillSymbolLayer(symbol_path, row, print_scale):
    svg_fill_symbol_layer = QgsSVGFillSymbolLayer(symbol_path)
    svg_fill_symbol_layer.setSvgFillColor(QColor(row[11]))
    svg_fill_symbol_layer.setPatternWidth(float(row[12]))
    svg_fill_symbol_layer.setSvgStrokeColor(QColor(row[11]))
    svg_fill_symbol_layer.setSvgStrokeWidth(float(0.0))
    svg_fill_symbol_layer.setDataDefinedProperty(
        QgsSymbolLayer.Property.PropertyWidth,
        QgsProperty.fromExpression(
            f"""
            calculate_size(@map_scale, {row[12]}, {print_scale})
            """
        ),
    )
    return svg_fill_symbol_layer


def main():
    # Check if the database path and properties file path are provided
    if len(sys.argv) != 9:
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
    config_file = sys.argv[8]

    # Load configuration once
    config = loadConfig(config_file)
    coordinate_reference_system = config.get("global", {}).get(
        "coordinate_reference_system"
    )
    print_scale = float(config.get("park", {}).get(np, {}).get("print_scale"))
    symbol_background_svg = config.get("global", {}).get("symbol_background_svg")
    project_title = config.get("park", {}).get(np, {}).get("boundary_name")

    # Initialize QGIS Application in headless mode (for standalone scripts)
    QgsApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # New QGIS project
    project = QgsProject.instance()
    project.setCrs(QgsCoordinateReferenceSystem(coordinate_reference_system))
    project.setTitle(project_title)
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
        # Skip the first row (header)
        next(file)

        # Read the file from the bottom to the top so that natural layer order is preserved
        reader = csv.reader(file.readlines()[::-1], delimiter="|")

        for row in reader:
            uri.setDataSource("", row[1], "geom", row[2], "ogc_fid")

            # Create a new vector layer from the URI
            layer = QgsVectorLayer(uri.uri(), row[13], "spatialite")

            # Check if the layer is valid
            if layer.isValid():
                if layer.geometryType() == Qgis.GeometryType.Polygon:
                    symbol = QgsFillSymbol.createSimple(
                        {
                            "color": row[3],
                            "outline_color": row[4],
                            "outline_width": row[5],
                        }
                    )

                    if float(row[5]) == 0:
                        symbol.symbolLayer(0).setStrokeStyle(Qt.PenStyle.NoPen)

                    if Path(symbol_path + "/" + row[0] + ".svg").exists():
                        symbol.appendSymbolLayer(
                            createSVGFillSymbolLayer(
                                symbol_path + "/" + row[0] + ".svg", row, print_scale
                            )
                        )

                    match row[14]:
                        case "":
                            pass
                        case "DotLine":
                            symbol.symbolLayer(0).setStrokeStyle(Qt.PenStyle.DotLine)
                        case "DashLine":
                            symbol.symbolLayer(0).setStrokeStyle(Qt.PenStyle.DashLine)
                        case "DashDotDotLine":
                            symbol.symbolLayer(0).setStrokeStyle(
                                Qt.PenStyle.DashDotDotLine
                            )
                        case "NoPen":
                            symbol.symbolLayer(0).setStrokeStyle(Qt.PenStyle.NoPen)

                    # Setting the blending mode
                    match row[15]:
                        case "":
                            pass
                        case "Multiply":
                            layer.setBlendMode(QPainter.CompositionMode_Multiply)
                        case "Overlay":
                            layer.setBlendMode(QPainter.CompositionMode_Overlay)
                elif layer.geometryType() == Qgis.GeometryType.Line:
                    symbol = QgsLineSymbol.createSimple(
                        {
                            "color": row[4],
                            "width": float(row[5]) * 1.5,
                            "capstyle": "round",
                        }
                    )
                    inner_line = QgsSimpleLineSymbolLayer()
                    inner_line.setColor(QColor(row[3]))
                    inner_line.setWidth(float(row[5]))
                    match row[14]:
                        case "":
                            pass
                        case "DotLine":
                            inner_line.setPenStyle(Qt.PenStyle.DotLine)
                        case "DashLine":
                            inner_line.setPenStyle(Qt.PenStyle.DashLine)
                        case "DashDotDotLine":
                            inner_line.setPenStyle(Qt.PenStyle.DashDotDotLine)
                    inner_line.setPenCapStyle(
                        Qt.PenCapStyle.RoundCap
                    )  # Set round end caps for lines
                    symbol.appendSymbolLayer(inner_line)

                    if row[0] == "embankment":
                        marker_symbol_layer = QgsSimpleMarkerSymbolLayer()
                        marker_symbol_layer.setSize(3)
                        # marker_symbol_layer.setColor(QColor("red"))
                        marker_symbol_layer.setStrokeColor(QColor("#333533"))
                        marker_symbol_layer.setStrokeWidth(0.5)
                        marker_symbol_layer.setShape(Qgis.MarkerShape.Line)
                        marker_symbol_layer.setAngle(
                            180
                        )  # Rotate the line to make it vertical
                        marker_symbol = QgsMarkerSymbol()
                        marker_symbol.changeSymbolLayer(0, marker_symbol_layer)
                        marker_line_symbol_layer = QgsMarkerLineSymbolLayer()
                        marker_line_symbol_layer.setSubSymbol(marker_symbol)
                        marker_line_symbol_layer.setInterval(3)
                        symbol.changeSymbolLayer(0, marker_line_symbol_layer)
                elif layer.geometryType() == Qgis.GeometryType.Point:
                    if Path(symbol_path + "/" + row[0] + ".svg").is_file():
                        symbol = QgsMarkerSymbol()
                        if (
                            row[10] == "yes" or row[10] == "yes+"
                        ):  # Enable background for the symbol
                            symbol.changeSymbolLayer(
                                0,
                                createSVGBackgroundSymbolLayer(
                                    symbol_background_svg,
                                    row,
                                    print_scale,
                                ),
                            )
                            symbol.appendSymbolLayer(
                                createSVGPOISymbolLayer(
                                    symbol_path + "/" + row[0] + ".svg",
                                    row,
                                    print_scale,
                                )
                            )
                        else:
                            symbol.changeSymbolLayer(
                                0,
                                createSVGPOISymbolLayer(
                                    symbol_path + "/" + row[0] + ".svg",
                                    row,
                                    print_scale,
                                ),
                            )
                    else:
                        symbol = QgsMarkerSymbol.createSimple(
                            {"name": "circle", "color": row[3], "size": row[5]}
                        )

                layer.setRenderer(QgsSingleSymbolRenderer(symbol))
                layer.renderer().symbol().setOpacity(float(row[6]))

                setLabel(row, layer, print_scale)

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
    print(f"Main map project created and saved at: {new_project_path}")

    # Clean up by closing the QGIS application
    qgs.exitQgis()


if __name__ == "__main__":
    main()
