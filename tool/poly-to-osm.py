import xml.etree.ElementTree as ET
from datetime import datetime
import sys

# Check if the database path and properties file path are provided
if len(sys.argv) < 3:
    print("Inadequate parameters.")
    sys.exit(1)

np = sys.argv[1]
poly_file = sys.argv[2]
output_osm_file = sys.argv[3]


def parse_poly_file(poly_file_path):
    # Parse a .poly file and return the list of polygons with their points.
    polygons = []
    with open(poly_file, "r") as f:
        current_polygon = []
        for line in f:
            line = line.strip()
            if line.startswith("END"):
                if current_polygon:
                    polygons.append(current_polygon)
                    current_polygon = []
            elif line.startswith(np) or line.startswith("!"):
                continue
            elif line:  # line contains coordinates
                lon, lat = map(float, line.split())
                current_polygon.append((lat, lon))
    return polygons


def generate_unique_id(base, counter):
    return int(hash(f"{base}_{counter}_{np}_sl_np_mapping") % 1e10)


def create_osm_file_from_poly(polygons, output_osm_file):
    # Create an OSM XML v0.6 file based on the parsed polygons, adding version and timestamp.
    # Root element of the OSM file
    osm = ET.Element("osm", version="0.6", generator="poly_to_osm_converter")

    node_id = 1
    way_id = 1

    timestamp = datetime.utcnow().isoformat() + "Z"

    for polygon in polygons:
        nodes = []

        # Create nodes for each point in the polygon
        for lat, lon in polygon:
            node_id = generate_unique_id(timestamp, node_id)
            node = ET.SubElement(
                osm,
                "node",
                id=str(node_id),
                lat=str(lat),
                lon=str(lon),
                version="1",
                timestamp=timestamp,
            )
            nodes.append(node_id)
            node_id += 1

        way_id = generate_unique_id(timestamp, way_id)
        way = ET.SubElement(
            osm, "way", id=str(way_id), version="1", timestamp=timestamp
        )

        first_node_ref = None
        for nd_id in nodes:
            if first_node_ref == None:
                first_node_ref = str(nd_id)
            ET.SubElement(way, "nd", ref=str(nd_id))

        # Add the first node again to close the way so that it would be a polygon
        ET.SubElement(way, "nd", ref=first_node_ref)
        ET.SubElement(way, "tag", k="area", v="yes")
        ET.SubElement(way, "tag", k="name", v=np + "_background")
        way_id += 1

    # Write to output OSM file
    tree = ET.ElementTree(osm)
    with open(output_osm_file, "wb") as f:
        tree.write(f, encoding="UTF-8", xml_declaration=True)


# Example usage
polygons = parse_poly_file(poly_file)
create_osm_file_from_poly(polygons, output_osm_file)

print(f"OSM file '{output_osm_file}' for the map area polygon created successfully.")