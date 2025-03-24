from pathlib import Path
import sys
from typing import Any, Dict

from PyQt5.QtCore import Qt
from osgeo import gdal
from qgis.core import QgsApplication, QgsLayoutExporter, QgsProject
from ruamel.yaml import YAML
from ruamel.yaml.parser import ParserError

gdal.PushErrorHandler("CPLQuietErrorHandler")

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


def loadProjectLayout(qgis_project_file, np, layout_name):
    project = QgsProject.instance()
    project.read(qgis_project_file)
    layout = project.layoutManager().layoutByName(layout_name)
    if not (project and layout):
        raise Exception(f"Project or layout not found!")
    else:
        return project, layout


def main():
    if len(sys.argv) != 7:
        print("Inadequate parameters.")
        sys.exit(1)

    np = sys.argv[1]
    scale = sys.argv[2]
    format = sys.argv[3]
    qgis_project_file = sys.argv[4]
    config_file = sys.argv[5]
    output_file = sys.argv[6]

    # Load configuration once
    config = loadConfig(config_file)
    layout_name = scale

    # QGIS environment
    QgsApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # Load the existing project
    project, layout = loadProjectLayout(qgis_project_file, np, layout_name)

    exporter = QgsLayoutExporter(layout)

    dpi = int(config.get("park", {}).get(np, {}).get("layout_" + scale, {}).get("dpi"))

    # Export to PDF
    if format == "pdf":
        pdf_settings = QgsLayoutExporter.PdfExportSettings()
        pdf_settings.pages = [0]

        pdf_result = exporter.exportToPdf(output_file, pdf_settings)

        if pdf_result != QgsLayoutExporter.ExportResult.Success:
            raise Exception("PDF export failed!")

        print("PDF exported successfully")
    elif format == "png":  # Export to PNG
        image_settings = QgsLayoutExporter.ImageExportSettings()
        image_settings.dpi = dpi
        image_settings.pages = [0]
        image_settings.generateWorldFile = False

        png_result = exporter.exportToImage(output_file, image_settings)

        if png_result != QgsLayoutExporter.ExportResult.Success:
            raise Exception("PNG export failed!")

        print("PNG exported successfully")

    qgs.exitQgis()


# Main execution
if __name__ == "__main__":
    main()
