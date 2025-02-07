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
)

from qgis.PyQt.QtCore import QRectF
from geopy.distance import geodesic

# Initialize QGIS application
# qgis_install_path = "C:/Path/To/QGIS"  # Replace with your QGIS installation path
# QgsApplication.setPrefixPath(qgis_install_path, True)


# Add the path to QGIS Python libraries
# sys.path.append(f"{qgis_install_path}/apps/qgis/python/plugins")


# Function to add a print layout to an existing project
def add_print_layout(
    project_path, layout_name, page_width, page_height, units, svg_path, scale
):
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # Load the existing project
    project = QgsProject.instance()
    project.read(project_path)
    project.layoutManager().removeLayout(
        project.layoutManager().layoutByName(layout_name)
    )
    print(f"Deleted existing layout '{layout_name}'.")

    # Create a new layout
    layout = QgsPrintLayout(project)
    layout.setName(layout_name)

    # Create a new page and set its size
    page = QgsLayoutItemPage(layout)
    page.setPageSize(QgsLayoutSize(page_width, page_height, units))

    # Add the page to the layout
    layout.pageCollection().addPage(page)
    # layout.refresh()

    # Add a map item to the layout
    map_item = QgsLayoutItemMap(layout)
    map_item.setFrameEnabled(False)
    map_item.setScale(scale)

    extent = project.instance().mapLayersByName("Park Canvas")[0].extent()
    xmin = extent.xMinimum()
    xmax = extent.xMaximum()
    ymin = extent.yMinimum()
    ymax = extent.yMaximum()

    width_mm = (geodesic((ymin, xmin), (ymin, xmax)).meters * 1000) / scale
    height_mm = (geodesic((ymin, xmin), (ymax, xmin)).meters * 1000) / scale

    print(width_mm, height_mm)

    map_item.setRect(QRectF(0, 0, width_mm, height_mm))  # Set map position and size
    map_item.setExtent(extent)  # Use the extent of the first layer
    # print(project.instance().mapLayersByName("Park Canvas")[0].extent())

    layout.addLayoutItem(map_item)

    # Add a scale bar
    scale_bar = QgsLayoutItemScaleBar(layout)
    scale_bar.setStyle("Single Box")  # Set scale bar style
    scale_bar.setUnits(QgsUnitTypes.DistanceKilometers)  # Set units for the scale bar
    scale_bar.setNumberOfSegments(2)  # Set number of segments
    scale_bar.setNumberOfSegmentsLeft(0)  # Set number of segments on the left
    scale_bar.setUnitsPerSegment(1)  # Set units per segment
    scale_bar.setLinkedMap(map_item)  # Link the scale bar to the map
    scale_bar.setPos(20, page.pageSize().height() - 70)  # Set position of the scale bar
    layout.addLayoutItem(scale_bar)

    # Add a legend
    legend = QgsLayoutItemLegend(layout)
    legend.setTitle("Legend")  # Set legend title
    legend.setLinkedMap(map_item)  # Link the legend to the map
    legend.setPos(page.pageSize().width() - 150, 20)  # Set position of the legend
    layout.addLayoutItem(legend)

    # # Add a windrose (SVG image)
    # windrose = QgsLayoutItemPicture(layout)
    # windrose.setPicturePath(svg_path)  # Set path to the SVG file
    # windrose.setPos(
    #     page.pageSize().width() - 50, page.pageSize().height() - 50
    # )  # Set position of the windrose
    # windrose.setScale(0.5)
    # layout.addLayoutItem(windrose)

    # Add the layout to the project
    project.layoutManager().addLayout(layout)

    # Save the project
    project.write()
    print(
        f"Added layout '{layout_name}' with page size {page.pageSize().width()}x{page.pageSize().height()} {units}."
    )

    # Exit QGIS application
    qgs.exitQgis()


# Main execution
if __name__ == "__main__":
    # Define project and layout parameters
    project_path = "/mnt/data2/Workspace/new/sl-np-mapping/qgis/hp.qgz"  # Replace with your project file path
    layout_name = "My Print Layout"
    page_width = 1828.8
    page_height = 1524
    units = QgsUnitTypes.LayoutMillimeters  # Units for page size
    svg_path = "/mnt/data2/Workspace/new/sl-np-mapping/symbol/compass-rose-6.svg"  # Replace with your SVG file path

    # Add the print layout to the existing project
    add_print_layout(
        project_path, layout_name, page_width, page_height, units, svg_path, 10000
    )
