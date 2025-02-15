import sys
from qgis.core import (
    QgsApplication,
    QgsProject,
    QgsLayout,
    QgsLayoutSize,
    QgsUnitTypes,
    QgsLayoutItemMap,
    QgsRectangle,
    QgsLayoutItemScaleBar,
    QgsLayoutItemLegend,
    QgsLayoutItemPicture,
    QgsPrintLayout,
    QgsLayoutItemPage,
    QgsLayoutPoint,
    QgsLayoutItem,
    QgsLegendStyle,
    QgsTextFormat,
    QgsLayoutItemLabel
)

from qgis.PyQt.QtCore import QRectF
from PyQt5.QtGui import QColor, QFont
from geopy.distance import geodesic
from pathlib import Path
from typing import Any, Dict
from ruamel.yaml import YAML
from ruamel.yaml.parser import ParserError

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

def calculateMapSize(project, scale):
    extent = project.instance().mapLayersByName("Park Canvas")[0].extent()
    xmin = extent.xMinimum()
    xmax = extent.xMaximum()
    ymin = extent.yMinimum()
    ymax = extent.yMaximum()
    
    width_mm = (geodesic((ymin, xmin), (ymin, xmax)).meters * 1000) / scale
    height_mm = (geodesic((ymin, xmin), (ymax, xmin)).meters * 1000) / scale
    return width_mm, height_mm, extent

def createPage(layout, width_mm, height_mm):
    page = QgsLayoutItemPage(layout)
    page.setPageSize(QgsLayoutSize(width_mm, height_mm, QgsUnitTypes.LayoutMillimeters))
    layout.pageCollection().addPage(page)
    return page

def addMap(config, layout, scale, width_mm, height_mm, extent):
    map = QgsLayoutItemMap(layout)
    map.setFrameEnabled(False)
    map.setScale(int(scale))
    map.setRect(QRectF(0, 0, width_mm, height_mm))  # Set map position and size
    map.setBackgroundEnabled(True)
    map.setBackgroundColor(QColor("#eeeeee"))
    map.setExtent(extent)
    layout.addLayoutItem(map)
    return map

def addScale(config, layout, map, page):
    scale_bar = QgsLayoutItemScaleBar(layout)
    scale_bar.setStyle("Numeric")  # Set scale bar style
    scale_bar.setUnits(QgsUnitTypes.DistanceKilometers)  # Set units for the scale bar
    scale_bar.setReferencePoint(QgsLayoutItem.LowerMiddle)
    scale_bar.setNumberOfSegments(2)  # Set number of segments
    scale_bar.setNumberOfSegmentsLeft(0)  # Set number of segments on the left
    scale_bar.setUnitsPerSegment(1)  # Set units per segment
    scale_bar.setLinkedMap(map)  # Link the scale bar to the map
    scale_bar.setPos(20, page.pageSize().height() - 70)  # Set position of the scale bar
    scale_bar.attemptMove(QgsLayoutPoint(page.pageSize().width()/2, page.pageSize().height() - 25, QgsUnitTypes.LayoutMillimeters))
    
    scale_text_format = QgsTextFormat()
    scale_text_format.setFont(QFont("Lato"))  # Font, size, weight, italic
    scale_text_format.setSize(52)
    #scale_text_format.setColor(QColor(0, 0, 0))  # Black text
    scale_bar.setTextFormat(scale_text_format)
    layout.addLayoutItem(scale_bar)
    return scale_bar


def addLegend(config, layout, map, page):
    legend = QgsLayoutItemLegend(layout)
    legend.setLinkedMap(map)
    legend.setReferencePoint(QgsLayoutItem.LowerRight)
    legend.setColumnCount(1)
    legend.setLegendFilterByMapEnabled(True)
    legend.setTitle("Legend")
    legend.setBackgroundColor(QColor("#eeeeee"))
    
    legend_title_style = legend.rstyle(QgsLegendStyle.Title)
    legend_title_format = legend_title_style.textFormat()
    legend_title_font = QFont("Lato")
    legend_title_format.setSize(40)
    legend_title_format.setFont(legend_title_font)
    
    legend_label_style = legend.rstyle(QgsLegendStyle.SymbolLabel)
    legend_label_format = legend_label_style.textFormat()
    legend_label_font = QFont("Lato")
    legend_label_format.setSize(20)
    legend_label_format.setFont(legend_label_font)
    
    legend.attemptMove(QgsLayoutPoint(page.pageSize().width() - 25, page.pageSize().height() - 25, QgsUnitTypes.LayoutMillimeters))
    layout.addLayoutItem(legend)
    return legend


def addCompassRose(config, layout, page, svg):
    windrose = QgsLayoutItemPicture(layout)
    windrose.setReferencePoint(QgsLayoutItem.UpperLeft)
    windrose.setPicturePath(svg)
    windrose.attemptMove(QgsLayoutPoint(page.pageSize().width() - 100 - 25, 25, QgsUnitTypes.LayoutMillimeters))
    windrose.attemptResize(QgsLayoutSize(100, 100, QgsUnitTypes.LayoutMillimeters))
    layout.addLayoutItem(windrose)
    return windrose

def addQR(config, layout, page, svg):
    qr = QgsLayoutItemPicture(layout)
    qr.setReferencePoint(QgsLayoutItem.LowerLeft)
    qr.setPicturePath(svg)
    qr.attemptResize(QgsLayoutSize(70, 70, QgsUnitTypes.LayoutMillimeters))
    qr.attemptMove(QgsLayoutPoint(25, page.pageSize().height() - 25, QgsUnitTypes.LayoutMillimeters))
    layout.addLayoutItem(qr)
    return qr

def addMapTitle(config, layout):
    map_title = QgsLayoutItemLabel(layout)
    map_title.setText("Hortan Plains National Park")
    
    # Font
    map_title_format = QgsTextFormat()
    map_title_format.setFont(QFont("Lato"))
    map_title_format.setSize(140)
    map_title_format.setColor(QColor("#eeeeee"))
    map_title.setTextFormat(map_title_format)
    
    # Background
    map_title.setBackgroundEnabled(True)
    map_title.setBackgroundColor(QColor("#346751"))  # Yellow background
    map_title.setReferencePoint(QgsLayoutItem.UpperLeft)
    map_title.attemptMove(QgsLayoutPoint(25, 25, QgsUnitTypes.LayoutMillimeters))
    map_title.attemptResize(QgsLayoutSize(608, 60, QgsUnitTypes.LayoutMillimeters))
    
    layout.addLayoutItem(map_title)
    return map_title


def loadProject(base_dir, np, layout_name):
    project = QgsProject.instance()
    project.read(base_dir + "/qgis/" + np + ".qgz")
    project.layoutManager().removeLayout(project.layoutManager().layoutByName(layout_name))
    print(f"Deleted existing layout '{layout_name}'.")
    return project


def createPrintLayout(project, layout_name):
    layout = QgsPrintLayout(project)
    layout.setName(layout_name)
    return layout


def main():
    if len(sys.argv) < 2:
        print("Inadequate parameters.")
        sys.exit(1)

    np = sys.argv[1]
    base_dir = sys.argv[2]
    scale = sys.argv[3]
    
     # Load configuration once
    config = loadConfig(base_dir + "/conf/sl-np-mapping.yaml")
    layout_name = scale

    # QGIS environment    
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # Load the existing project
    project = loadProject(base_dir, np, layout_name)

    # Create a new layout
    layout = createPrintLayout(project, layout_name)

    width_mm, height_mm, extent = calculateMapSize(project, int(scale))

    # Create page
    page = createPage(layout, width_mm, height_mm)

    # Add a map item to the layout
    map = addMap(config, layout, scale, width_mm, height_mm, extent)
    
    # Add a scale bar
    scale_bar = addScale(config, layout, map, page)    

    # Add a legend
    legend = addLegend(config, layout, map, page)

    # Add a compass rose (SVG image)
    compass_rose_svg = base_dir + "/symbol/" + config.get("park", {}).get(np, {}).get("print_layout_" + scale, {}).get("compass_rose", {}).get("svg") + ".svg"
    compass_rose = addCompassRose(config, layout, page, compass_rose_svg)
        
    # Add the QR (SVG image)
    qr_svg = base_dir + "/info-01.svg"
    qr = addQR(config, layout, page, qr_svg)

    map_title = addMapTitle(config, layout)

    # Add the layout to the project
    project.layoutManager().addLayout(layout)

    # Save the project
    project.write()
    print(f"Added layout '{layout_name}' with page size {page.pageSize().width()}x{page.pageSize().height()}.")

    # Exit QGIS application
    qgs.exitQgis()


# Main execution
if __name__ == "__main__":
    main()
