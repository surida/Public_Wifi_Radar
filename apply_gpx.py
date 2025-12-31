
import xml.etree.ElementTree as ET
import subprocess
import sys

def apply_gpx(gpx_file, device_id):
    tree = ET.parse(gpx_file)
    root = tree.getroot()
    
    # namespaces
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    
    points = []
    for trkpt in root.findall('.//gpx:trkpt', ns):
        lat = trkpt.get('lat')
        lon = trkpt.get('lon')
        points.append(f"{lat},{lon}")
    
    if not points:
        print("No points found in GPX.")
        return

    # Calculate speed roughly (1km in 2 mins = ~8.33 m/s)
    # The generation script used 8.33 m/s
    speed = 8.33
    
    print(f"Found {len(points)} points. Applying to device {device_id}...")
    
    # Chunking might be needed if too long, but let's try all at once.
    # simctl documentation says: "At least two waypoints are required. Use '-' to read waypoints from stdin"
    # Reading from stdin is safer for large inputs!
    
    cmd = ["xcrun", "simctl", "location", device_id, "start", f"--speed={speed}", "-"]
    
    process = subprocess.Popen(cmd, stdin=subprocess.PIPE, text=True)
    
    stdin_content = "\n".join(points)
    process.communicate(input=stdin_content)
    
    if process.returncode == 0:
        print("Successfully started simulation.")
    else:
        print("Failed to start simulation.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 apply_gpx.py <gpx_file> <device_id>")
        sys.exit(1)
        
    apply_gpx(sys.argv[1], sys.argv[2])
