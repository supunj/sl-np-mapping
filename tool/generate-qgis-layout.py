from pathlib import Path
import sys
from typing import Any, Dict

from PIL import Image
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QColor, QFont
from geopy.distance import geodesic
from qgis.PyQt.QtCore import QRectF
from qgis.core import (
    Qgis,
    QgsApplication,
    QgsLayoutItem,
    QgsLayoutItemLabel,
    QgsLayoutItemLegend,
    QgsLayoutItemMap,
    QgsLayoutItemPage,
    QgsLayoutItemPicture,
    QgsLayoutItemScaleBar,
    QgsLayoutPoint,
    QgsLayoutSize,
    QgsLegendStyle,
    QgsPrintLayout,
    QgsProject,
    QgsScaleBarSettings,
    QgsTextFormat,
)
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
    extent = project.mapLayersByName("Park Canvas")[0].extent()
    xmin = extent.xMinimum()
    xmax = extent.xMaximum()
    ymin = extent.yMinimum()
    ymax = extent.yMaximum()

    width_mm = (geodesic((ymin, xmin), (ymin, xmax)).meters * 1000) / float(scale)
    height_mm = (geodesic((ymin, xmin), (ymax, xmin)).meters * 1000) / float(scale)
    return width_mm, height_mm, extent


def createPage(layout, width_mm, height_mm):
    page = QgsLayoutItemPage(layout)
    page.setPageSize(QgsLayoutSize(width_mm, height_mm, Qgis.LayoutUnit.Millimeters))
    layout.pageCollection().addPage(page)
    return page


def addMap(config, np, scale, layout, width_mm, height_mm, extent):
    background_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("map", {})
        .get("background_colour")
    )
    map = QgsLayoutItemMap(layout)
    map.setId("Main Map")
    map.setRect(QRectF(0, 0, width_mm, height_mm))
    map.setExtent(extent)
    map.zoomToExtent(extent)
    map.setScale(float(scale))
    map.setFrameEnabled(False)
    map.setBackgroundEnabled(True)
    map.setBackgroundColor(QColor(background_colour))
    layout.addLayoutItem(map)
    return map


def addScale(config, np, scale, layout, map, page, margin):
    text_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("scale", {})
        .get("text_colour")
    )
    background_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("scale", {})
        .get("background_colour")
    )
    font = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("scale", {})
        .get("font")
    )
    font_size = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("scale", {})
        .get("font_size")
    )

    scale_bar = QgsLayoutItemScaleBar(layout)
    scale_bar.setId("Scale")
    scale_bar.setLinkedMap(map)
    scale_bar.setStyle("Numeric")
    scale_bar.setAlignment(QgsScaleBarSettings.Alignment.AlignMiddle)
    scale_bar.setBackgroundEnabled(True)
    scale_bar.setBackgroundColor(QColor(background_colour))
    scale_bar.setReferencePoint(QgsLayoutItem.ReferencePoint.LowerMiddle)
    scale_bar.attemptMove(
        QgsLayoutPoint(
            page.pageSize().width() / 2,
            page.pageSize().height() - margin,
            Qgis.LayoutUnit.Millimeters,
        )
    )

    scale_text_format = QgsTextFormat()
    scale_text_format.setFont(QFont(font))
    scale_text_format.setSize(font_size)
    scale_text_format.setColor(QColor(text_colour))
    scale_bar.setTextFormat(scale_text_format)

    layout.addLayoutItem(scale_bar)
    return scale_bar


def addLegend(config, np, scale, layout, map, page, margin):
    columns = int(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("columns")
    )
    text_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("text_colour")
    )
    background_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("background_colour")
    )
    font = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("font")
    )
    font_size = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("font_size")
    )
    symbol_size = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("symbol_size")
    )
    item_spacing = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("legend", {})
        .get("item_spacing")
    )

    legend = QgsLayoutItemLegend(layout)
    legend.setId("Legend")
    legend.setLinkedMap(map)
    legend.setReferencePoint(QgsLayoutItem.ReferencePoint.LowerRight)
    legend.setAutoUpdateModel(False)
    removeCertainLegendItems(legend)  # Remove unnecessary legend items
    legend.setColumnCount(columns)
    legend.setEqualColumnWidth(True)
    legend.setLegendFilterByMapEnabled(True)
    legend.setTitle("Legend")
    legend.setBackgroundColor(QColor(background_colour))
    legend.setSymbolWidth(symbol_size)
    legend.setSymbolHeight(symbol_size)
    legend.setColumnSpace(item_spacing)
    legend.setStyleMargin(QgsLegendStyle.Style.Symbol, item_spacing)
    legend.setStyleMargin(QgsLegendStyle.Style.SymbolLabel, 0)

    legend_title_style = legend.rstyle(QgsLegendStyle.Style.Title)
    legend_title_format = legend_title_style.textFormat()
    legend_title_format.setFont(QFont(font))
    legend_title_format.setSize(font_size * 2)  # Twice the size of legend labels
    legend_title_format.setColor(QColor(text_colour))

    legend_label_style = legend.rstyle(QgsLegendStyle.Style.SymbolLabel)
    legend_label_format = legend_label_style.textFormat()
    legend_label_format.setFont(QFont(font))
    legend_label_format.setSize(font_size)
    legend_label_format.setColor(QColor(text_colour))
    legend.attemptMove(
        QgsLayoutPoint(
            page.pageSize().width() - margin,
            page.pageSize().height() - margin,
            Qgis.LayoutUnit.Millimeters,
        )
    )
    layout.addLayoutItem(legend)
    return legend


def removeCertainLegendItems(legend):
    root = legend.model().rootGroup()
    layers_to_remove = {"Park Canvas", "hill_shade", "park_outer_glow"}

    for layer_node in reversed(list(root.findLayers())):
        if layer_node.layer().name() in layers_to_remove:
            parent = layer_node.parent()
            parent.removeChildNode(layer_node)
    return


def addCompassRose(config, np, scale, layout, page, compass_rose_svg, margin):
    size = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("compass_rose", {})
        .get("size")
    )

    compass_rose = QgsLayoutItemPicture(layout)
    compass_rose.setId("Compass Rose")
    compass_rose.setReferencePoint(QgsLayoutItem.ReferencePoint.UpperLeft)
    compass_rose.setPicturePath(compass_rose_svg)
    compass_rose.attemptMove(
        QgsLayoutPoint(
            page.pageSize().width() - size - margin, margin, Qgis.LayoutUnit.Millimeters
        )
    )
    compass_rose.attemptResize(QgsLayoutSize(size, size, Qgis.LayoutUnit.Millimeters))
    layout.addLayoutItem(compass_rose)
    return compass_rose


def addQR(config, np, scale, layout, page, qr_svg, margin):
    size = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("qr", {})
        .get("size")
    )

    qr = QgsLayoutItemPicture(layout)
    qr.setId("QR")
    qr.setReferencePoint(QgsLayoutItem.ReferencePoint.LowerLeft)
    qr.setPicturePath(qr_svg)
    qr.attemptResize(QgsLayoutSize(size, size, Qgis.LayoutUnit.Millimeters))
    qr.attemptMove(
        QgsLayoutPoint(
            margin, page.pageSize().height() - margin, Qgis.LayoutUnit.Millimeters
        )
    )
    layout.addLayoutItem(qr)
    return qr


def addMapTitle(config, np, scale, layout, margin):
    width = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("width")
    )
    height = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("height")
    )
    text = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("text")
    )
    text_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("text_colour")
    )
    background_colour = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("background_colour")
    )
    font = (
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("font")
    )
    font_size = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("title", {})
        .get("font_size")
    )

    map_title = QgsLayoutItemLabel(layout)
    map_title.setId("Main Title")
    map_title.setText(text)
    map_title.setHAlign(Qt.AlignmentFlag.AlignHCenter)
    map_title.setVAlign(Qt.AlignmentFlag.AlignVCenter)

    # Font
    map_title_format = QgsTextFormat()
    map_title_format.setFont(QFont(font))
    map_title_format.setSize(font_size)
    map_title_format.setColor(QColor(text_colour))
    map_title.setTextFormat(map_title_format)

    # Background
    map_title.setBackgroundEnabled(True)
    map_title.setBackgroundColor(QColor(background_colour))
    map_title.setReferencePoint(QgsLayoutItem.ReferencePoint.UpperLeft)
    map_title.attemptMove(QgsLayoutPoint(margin, margin, Qgis.LayoutUnit.Millimeters))
    map_title.attemptResize(QgsLayoutSize(width, height, Qgis.LayoutUnit.Millimeters))

    layout.addLayoutItem(map_title)
    return map_title


def calculateOverviewMapSize(config, np, scale, overview_map_png):
    scale_factor = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("overview_map", {})
        .get("scale_factor")
    )

    with Image.open(overview_map_png) as img:
        width, height = img.size

    return width / scale_factor, height / scale_factor


def addOverviewMap(config, np, scale, layout, page, overview_map_png, margin):
    position_x = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("overview_map", {})
        .get("position_x")
    )
    position_y = float(
        config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("overview_map", {})
        .get("position_y")
    )

    overview_map = QgsLayoutItemPicture(layout)
    overview_map.setId("Overview Map")
    overview_map.setReferencePoint(QgsLayoutItem.ReferencePoint.UpperLeft)
    overview_map.setPicturePath(overview_map_png)

    width, height = calculateOverviewMapSize(config, np, scale, overview_map_png)

    overview_map.attemptResize(
        QgsLayoutSize(width, height, Qgis.LayoutUnit.Millimeters)
    )
    overview_map.attemptMove(
        QgsLayoutPoint(position_x, position_y, Qgis.LayoutUnit.Millimeters)
    )
    layout.addLayoutItem(overview_map)
    return overview_map


def loadProject(base_dir, np):
    project = QgsProject.instance()
    project.read(base_dir + "/qgis/" + np + ".qgz")
    return project


def createPrintLayout(config, np, scale, project, layout_name):
    dpi = int(config.get("park", {}).get(np, {}).get("layout_" + scale, {}).get("dpi"))
    layout = QgsPrintLayout(project)
    layout.setName(layout_name)
    layout.renderContext().setDpi(dpi)
    return layout


def main():
    if len(sys.argv) != 5:
        print("Inadequate parameters.")
        sys.exit(1)

    np = sys.argv[1]
    scale = sys.argv[2]
    config_file = sys.argv[3]
    base_dir = sys.argv[4]

    # Load configuration once
    config = loadConfig(config_file)
    margin = float(
        config.get("park", {}).get(np, {}).get("layout_" + scale, {}).get("margin")
    )
    compass_rose_svg = (
        base_dir
        + "/symbol/"
        + config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("compass_rose", {})
        .get("svg")
        + ".svg"
    )
    qr_svg = (
        base_dir
        + "/"
        + config.get("park", {})
        .get(np, {})
        .get("layout_" + scale, {})
        .get("qr", {})
        .get("svg")
        + ".svg"
    )
    overview_map_png = (
        base_dir
        + "/render/"
        + np
        + "/"
        + config.get("park", {}).get(np, {}).get("output_file_name")
        + "_Overview.png"
    )
    layout_name = scale

    # QGIS environment
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # Load the existing project
    project = loadProject(base_dir, np)

    # Delete the layout if exists
    project.layoutManager().removeLayout(
        project.layoutManager().layoutByName(layout_name)
    )
    print(f"Deleted existing layout '{layout_name}'.")

    # Create a new layout
    layout = createPrintLayout(config, np, scale, project, layout_name)

    width_mm, height_mm, extent = calculateMapSize(project, scale)

    # Create page
    page = createPage(layout, width_mm, height_mm)

    # Add the map
    map = addMap(config, np, scale, layout, width_mm, height_mm, extent)

    # Add the scale bar
    scale_bar = addScale(config, np, scale, layout, map, page, margin)

    # Add the legend
    legend = addLegend(config, np, scale, layout, map, page, margin)

    # Add a compass rose (SVG image)
    compass_rose = addCompassRose(
        config, np, scale, layout, page, compass_rose_svg, margin
    )

    # Add the QR (SVG image)
    qr = addQR(config, np, scale, layout, page, qr_svg, margin)

    # Title
    map_title = addMapTitle(config, np, scale, layout, margin)

    # Overview map
    overview_map = addOverviewMap(
        config, np, scale, layout, page, overview_map_png, margin
    )

    # Add the layout to the project
    project.layoutManager().addLayout(layout)

    # Save the project
    project.write()
    print(
        f"Added layout '{layout_name}' with page size {page.pageSize().width()}x{page.pageSize().height()}."
    )

    # Exit QGIS application
    qgs.exitQgis()


# Main execution
if __name__ == "__main__":
    main()
