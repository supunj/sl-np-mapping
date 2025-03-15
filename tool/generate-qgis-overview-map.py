from pathlib import Path
import sys
from typing import Any, Dict

from PyQt5.QtCore import Qt
from PyQt5.QtGui import QColor
from osgeo import gdal
from qgis.core import (
    Qgis,
    QgsApplication,
    QgsCoordinateReferenceSystem,
    QgsDataSourceUri,
    QgsDistanceArea,
    QgsFillSymbol,
    QgsLayoutExporter,
    QgsLayoutItemMap,
    QgsLayoutItemPage,
    QgsLayoutPoint,
    QgsLayoutSize,
    QgsLineSymbol,
    QgsMarkerSymbol,
    QgsMarkerSymbol,
    QgsPrintLayout,
    QgsProject,
    QgsSimpleFillSymbolLayer,
    QgsSingleSymbolRenderer,
    QgsUnitTypes,
    QgsVectorLayer,
)
from ruamel.yaml import YAML
from ruamel.yaml.parser import ParserError

gdal.PushErrorHandler('CPLQuietErrorHandler')

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

def createQGISProject(coordinate_reference_system, np, db_path):
    qgs = QgsApplication([], False)
    qgs.initQgis()

    project = QgsProject.instance()
    project.setCrs(QgsCoordinateReferenceSystem(coordinate_reference_system))
    project.setTitle(np)
    project.writeEntry("Paths", "Absolute", False)  # Set paths to relative
    
    uri = QgsDataSourceUri()
    uri.setDatabase(db_path)
    
    tables_layers = [
                        ["sl_landmass", "SL Landmass", "#eeeeee", 0], 
                        ["park_boundary", "Park Boundary", "#346751", 0]
                    ]
    
    for table_layer in tables_layers:
        uri.setDataSource("", table_layer[0], "geom", "", "ogc_fid")
        layer = QgsVectorLayer(uri.uri(), table_layer[1], "spatialite")
    
        symbol = None

        if layer.isValid():
            if layer.geometryType() == Qgis.GeometryType.Polygon:
                symbol = QgsFillSymbol.createSimple(
                    {
                        "color": table_layer[2],
                        "outline_color": "#1b4332",
                        "outline_width": table_layer[3],
                    }
                )
                
                if table_layer[3] == 0:
                    symbol.symbolLayer(0).setStrokeStyle(Qt.PenStyle.NoPen)
            elif layer.geometryType() == Qgis.GeometryType.Line:
                symbol = QgsLineSymbol.createSimple(
                    {
                        "color": table_layer[2], 
                        "width": table_layer[3]
                    }
                )
            elif layer.geometryType() == Qgis.GeometryType.Point:
                symbol = QgsMarkerSymbol.createSimple(
                    {
                        "name": "circle",
                        "color": table_layer[2],
                        "size": table_layer[3]
                    }
                )
    
            layer.setRenderer(QgsSingleSymbolRenderer(symbol))

            project.addMapLayer(layer)
        else:
            print("Layer failed to load.")    
    
    return qgs, project

def calculatePageSize(project, extent, scale):
    # Calculate extent dimensions in meters
    da = QgsDistanceArea()
    da.setSourceCrs(project.crs(), project.transformContext())
    extent_width = da.convertLengthMeasurement(extent.width(), Qgis.DistanceUnit.Meters)
    extent_height = da.convertLengthMeasurement(extent.height(), Qgis.DistanceUnit.Meters)

    # Calculate page size in millimeters
    page_width_mm = (extent_width * 1000) / float(scale)
    page_height_mm = (extent_height * 1000) / float(scale)

    return page_width_mm, page_height_mm

def createLayout(project, scale, layout_name):
    layout = QgsPrintLayout(project)
    layout.setName(layout_name)
    layout.renderContext().setDpi(300)

    extent = project.mapLayersByName("SL Landmass")[0].extent()   

    page = QgsLayoutItemPage(layout)
    page_width_mm, page_height_mm = calculatePageSize(project, extent, scale)
    page.setPageSize(QgsLayoutSize(page_width_mm, page_height_mm, Qgis.LayoutUnit.Millimeters))
    page.setBackgroundEnabled(True)
    
    # Page transparency
    fill_symbol = QgsFillSymbol()
    fill_symbol.deleteSymbolLayer(0)
    transparent_fill = QgsSimpleFillSymbolLayer()
    transparent_fill.setColor(QColor(0, 0, 0, 0))
    transparent_fill.setStrokeStyle(Qt.PenStyle.NoPen)    
    fill_symbol.appendSymbolLayer(transparent_fill)
    page.setPageStyleSymbol(fill_symbol)

    page.setFrameEnabled(False)
    layout.pageCollection().addPage(page)
    
    map = QgsLayoutItemMap(layout)
    map.setId("Overview Map")
    map.setScale(float(scale))
    map.setExtent(extent)    
    map.zoomToExtent(extent)
    map.setFrameEnabled(False)
    map.setBackgroundEnabled(False)
    map.attemptResize(QgsLayoutSize(page_width_mm, page_height_mm, Qgis.LayoutUnit.Millimeters))
    map.attemptMove(QgsLayoutPoint(0, 0, Qgis.LayoutUnit.Millimeters))
    
    layout.addLayoutItem(map)
    return layout

def exportToSVG(layout, svg_file_path):
    if layout:
        exporter = QgsLayoutExporter(layout)
        settings = exporter.SvgExportSettings()
        settings.forceVectorOutput = False
        settings.cropToContents = True
        settings.exportMetadata = False
        settings.simplifyGeometries = False
        result = exporter.exportToSvg(svg_file_path, settings)

        if result == QgsLayoutExporter.ExportResult.Success:
            print(f"Successfully exported layout to {svg_file_path}")
        else:
            print("Export failed. Error:", result)

        return result
    else:
        print(f"Layout not found.")
        return None

def exportToPNG(layout, png_file_path):
    if layout:
        exporter = QgsLayoutExporter(layout)
        image_settings = QgsLayoutExporter.ImageExportSettings()
        image_settings.pages = [0]
        image_settings.generateWorldFile = False

        result = exporter.exportToImage(png_file_path, image_settings)
        
        if result != QgsLayoutExporter.ExportResult.Success:
             raise Exception("PNG export failed!")
        
        return result
    else:
        print(f"Layout not found.")
        return None

def main():
    # Check if the database path and properties file path are provided
    if len(sys.argv) != 7:
        print("Inadequate parameters.")
        sys.exit(1)

    np = sys.argv[1]
    config_file = sys.argv[2]
    db_path = sys.argv[3]
    overview_project_path = sys.argv[4]
    output_file_path = sys.argv[5]
    format = sys.argv[6]

    config = loadConfig(config_file)
    coordinate_reference_system = config.get("global", {}).get("coordinate_reference_system")
    scale = config.get("park", {}).get(np, {}).get("overview_map", {}).get("scale")
    layout_name = config.get("park", {}).get(np, {}).get("overview_map", {}).get("layout_name")

    qgs, project = createQGISProject(coordinate_reference_system, np, db_path)
    layout = createLayout(project, scale, layout_name)
    project.layoutManager().addLayout(layout)
    project.write(overview_project_path)
    print(f"Overview map project created and saved at: {overview_project_path}")

    if format == "svg":
        result = exportToSVG(project.layoutManager().layoutByName(layout_name), output_file_path)
    elif format == "png":
        result = exportToPNG(project.layoutManager().layoutByName(layout_name), output_file_path)

    qgs.exitQgis()

if __name__ == "__main__":
    main()
