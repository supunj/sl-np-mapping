import sys
from qgis.core import (
    QgsApplication, QgsProject, QgsPrintLayout, QgsLayoutItemMap,
    QgsLayoutItemLabel, QgsLayoutItemLegend, QgsLayoutItemScaleBar,
    QgsLayoutItemPicture, QgsLayoutExporter,
    QgsLayoutPoint, QgsLayoutSize, QgsReadWriteContext, QgsRectangle, QgsLayoutItemPage
)
from qgis.PyQt.QtCore import QRectF
from qgis.PyQt.QtGui import QFont

def create_print_layout(project_path, layout_name, scale, title_text):
    # Initialize QGIS
    qgs = QgsApplication([], False)
    qgs.initQgis()

    # Load project
    project = QgsProject.instance()
    if not project.read(project_path):
        raise ValueError(f"Failed to load project: {project_path}")

    # Create a new print layout
    layout = QgsPrintLayout(project)
    layout.setName(layout_name)  # Set layout name
    
    # Add a page to the layout
    page_collection = layout.pageCollection()
    page_collection.addPage(QgsLayoutItemPage(layout))  # Add a new page
    page = page_collection.pages()[0]  # Retrieve the first page
    page.setPageSize(QgsLayoutSize(1, 1, layout.units()))  # Temporary 1x1mm size

    # Add map item to the layout
    map_item = QgsLayoutItemMap(layout)
    map_item.setFrameEnabled(True)
    map_item.setScale(scale)

    # Calculate combined extent of all layers
    layers = list(project.mapLayers().values())
    if not layers:
        raise ValueError("No layers found in the project!")
        
    combined_extent = QgsRectangle()
    for layer in layers:
        combined_extent.combineExtentWith(layer.extent())
        
    # Calculate map dimensions in mm based on scale
    width_m = combined_extent.width()
    height_m = combined_extent.height()
    map_width_mm = (width_m * 1000) / scale  # Convert meters to mm at scale
    map_height_mm = (height_m * 1000) / scale
    
    # Set map item position and size
    map_item.setRect(QRectF(10, 30, map_width_mm, map_height_mm))
    map_item.setExtent(combined_extent)
    layout.addLayoutItem(map_item)

    # Add title
    title = QgsLayoutItemLabel(layout)
    title.setText(title_text)
    title.setFont(QFont("Arial", 18, QFont.Bold))
    title.adjustSizeToText()
    title.attemptMove(QgsLayoutPoint(10, 10, layout.units()))  # Position
    layout.addLayoutItem(title)

    # Add scale bar
    scale_bar = QgsLayoutItemScaleBar(layout)
    scale_bar.setLinkedMap(map_item)
    scale_bar.setStyle('Single Box')
    scale_bar.applyDefaultSize()
    scale_bar.attemptMove(QgsLayoutPoint(10, 220, layout.units()))  # Position
    layout.addLayoutItem(scale_bar)

    # Add legend
    legend = QgsLayoutItemLegend(layout)
    legend.setLinkedMap(map_item)
    legend.setTitle("Legend")
    legend.attemptMove(QgsLayoutPoint(200, 30, layout.units()))  # Position
    layout.addLayoutItem(legend)

    # Add wind rose (image)
    wind_rose = QgsLayoutItemPicture(layout)
    wind_rose.setPicturePath("/mnt/data2/Workspace/new/sl-np-mapping/symbol/compass-rose-6.svg")  # Replace with your image
    wind_rose.attemptResize(QgsLayoutSize(20, 20, layout.units()))  # Size
    wind_rose.attemptMove(QgsLayoutPoint(180, 10, layout.units()))  # Position
    layout.addLayoutItem(wind_rose)

    # Calculate page size with margins after all elements exist
    all_items = layout.items()
    margin = 10  # 10mm margin on all sides
    
    # Filter out non-QGIS layout items (e.g., QGraphicsRectItem)
    valid_items = [item for item in all_items if hasattr(item, 'pagePos')]

    # Get max extent of valid items
    max_right = max(item.pagePos().x() + item.rect().width() for item in valid_items)
    max_bottom = max(item.pagePos().y() + item.rect().height() for item in valid_items)
    
    # Calculate page size with margins
    page_width = max_right + margin * 2
    page_height = max_bottom + margin * 2
    
    # Set page size
    page.setPageSize(QgsLayoutSize(page_width, page_height, layout.units()))
    
    # Center map in available space
    map_item.attemptMove(QgsLayoutPoint(
        (page_width - map_item.rect().width()) / 2,
        (page_height - map_item.rect().height()) / 2,
        layout.units()
    ))
    
    # Reposition other elements relative to centered map
    title.attemptMove(QgsLayoutPoint(margin, margin, layout.units()))
    scale_bar.attemptMove(QgsLayoutPoint(
        margin,
        page_height - margin - scale_bar.rect().height(),
        layout.units()
    ))
    legend.attemptMove(QgsLayoutPoint(
        page_width - margin - legend.rect().width(),
        margin,
        layout.units()
    ))
    wind_rose.attemptMove(QgsLayoutPoint(
        page_width - margin - wind_rose.rect().width(),
        page_height - margin - wind_rose.rect().height(),
        layout.units()
    ))

    # Add the layout to the project
    project.layoutManager().addLayout(layout)

    # Save the project with the new layout
    project.write()

    # Cleanup
    qgs.exitQgis()

if __name__ == "__main__":
    project_path = "/mnt/data2/Workspace/new/sl-np-mapping/qgis/yb1.qgz"
    layout_name = "Automated Layout"  # Name for the new layout
    scale = 50000  # 1:50000 scale
    title_text = "Automated Map"

    create_print_layout(project_path, layout_name, scale, title_text)
