
import math
import datetime

def generate_gpx(filename):
    # Seoul City Hall coordinates
    center_lat = 37.5663
    center_lon = 126.9779
    
    # 1km circumference -> Radius approx 159 meters
    # 1 degree of latitude is approx 111,000 meters
    # 1 degree of longitude at this latitude is approx 111,000 * cos(lat) meters
    
    circumference_meters = 1000
    radius_meters = circumference_meters / (2 * math.pi)
    
    lat_degree_per_meter = 1 / 111000.0
    lon_degree_per_meter = 1 / (111000.0 * math.cos(math.radians(center_lat)))
    
    # Speed: 30 km/h = ~8.33 m/s (Driving speed)
    speed_mps = 8.33
    total_duration_seconds = int(circumference_meters / speed_mps)
    
    # Generate points every 1 second for smoother fast movement
    interval_seconds = 1
    num_points = int(total_duration_seconds / interval_seconds)
    
    gpx_header = """<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="SeoulWalkGenerator" 
  xmlns="http://www.topografix.com/GPX/1/1" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <trk>
    <name>Seoul City Hall 1km Walk</name>
    <trkseg>"""
    
    gpx_footer = """    </trkseg>
  </trk>
</gpx>"""
    
    start_time = datetime.datetime.now(datetime.timezone.utc)
    
    points = []
    
    for i in range(num_points + 1):
        # Calculate angle for circular path
        angle = (2 * math.pi * i) / num_points
        
        # Calculate offsets in meters
        dx = radius_meters * math.cos(angle) # East offset
        dy = radius_meters * math.sin(angle) # North offset
        
        # Convert to lat/lon offsets
        dlat = dy * lat_degree_per_meter
        dlon = dx * lon_degree_per_meter
        
        point_lat = center_lat + dlat
        point_lon = center_lon + dlon
        
        # Time
        point_time = start_time + datetime.timedelta(seconds=i * interval_seconds)
        time_str = point_time.strftime("%Y-%m-%dT%H:%M:%SZ")
        
        points.append(f'      <trkpt lat="{point_lat:.7f}" lon="{point_lon:.7f}">\n        <ele>0.0</ele>\n        <time>{time_str}</time>\n      </trkpt>')
        
    with open(filename, "w", encoding="utf-8") as f:
        f.write(gpx_header + "\n")
        f.write("\n".join(points) + "\n")
        f.write(gpx_footer)
        
    print(f"Generated {filename} with {len(points)} points.")

if __name__ == "__main__":
    generate_gpx("seoul_city_hall_walk.gpx")
