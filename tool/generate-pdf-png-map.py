from pathlib import Path
import sys
from typing import Any, Dict

from osgeo import gdal
from qgis.core import (
    QgsApplication,
    QgsLayoutExporter,
    QgsProject
)
from ruamel.yaml import YAML
from ruamel.yaml.parser import ParserError
gdal.PushErrorHandler('CPLQuietErrorHandler')

from PyQt5.QtCore import QSize

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

def loadProjectLayout(base_dir, np, layout_name):
    project = QgsProject.instance()
    project.read(base_dir + "/qgis/" + np + ".qgz")
    layout = project.layoutManager().layoutByName(layout_name)
    if not (project and layout):
        raise Exception(f"Project or layout not found!")
    else:
        return project, layout

def main():
    if len(sys.argv) != 5:
        print("Inadequate parameters.")
        sys.exit(1)

    np = sys.argv[1]
    scale = sys.argv[2]
    format = sys.argv[3]
    base_dir = sys.argv[4]
            
     # Load configuration once
    config = loadConfig(base_dir + "/conf/sl-np-mapping.yaml")
    layout_name = scale

    # QGIS environment    
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # Load the existing project
    project, layout = loadProjectLayout(base_dir, np, layout_name)
    
    # Create layout exporter
    exporter = QgsLayoutExporter(layout)

    output_file_name = config.get("park", {}).get(np, {}).get("layout_" + scale, {}).get("output_file_name")
    dpi = int(config.get("park", {}).get(np, {}).get("layout_" + scale, {}).get("dpi"))

    # Export to PDF
    if format == "pdf":
        pdf_settings = QgsLayoutExporter.PdfExportSettings()
        pdf_settings.pages = [0] 
            
        pdf_result = exporter.exportToPdf(base_dir + "/render/" + np + "/" + output_file_name + ".pdf", pdf_settings)
        
        if pdf_result != QgsLayoutExporter.ExportResult.Success:
            raise Exception("PDF export failed!")

        print(f"PDF exported successfully")
        
        sys.exit(0)
    
    # Export to PNG
    if format == "png":
        image_settings = QgsLayoutExporter.ImageExportSettings()
        image_settings.dpi = dpi
        image_settings.pages = [0]
        image_settings.generateWorldFile = False
        #image_settings.forceVectorOutput = False

        #grid_size = QSize(1000, 1000)

        png_result = exporter.exportToImage(base_dir + "/render/" + np + "/" + output_file_name + ".png", image_settings)
        
        # png_result = exporter.exportToTiledImage(
        #                                             base_dir + "/render/" + np,  # Folder to save tiles
        #                                             output_file_name,             # Base name for tiles (e.g., "map_tile_")
        #                                             "png",                       # Image format
        #                                             image_settings,
        #                                             gridSize=grid_size
        #                                         )

        if png_result != QgsLayoutExporter.ExportResult.Success:
            raise Exception("PNG export failed!")

        print(f"PNG exported successfully")

        sys.exit(0)

# Main execution
if __name__ == "__main__":
    main()