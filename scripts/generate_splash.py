#!/usr/bin/env python3
"""
Generate splash screen images for flutter_native_splash
- Creates properly sized images for Android 12+ and legacy platforms
- Extracts background color from original icon
"""

from PIL import Image, ImageDraw
import os

def get_dominant_corner_color(img):
    """Extract the dominant background color from corners"""
    img_rgba = img.convert("RGBA")
    corners = [
        img_rgba.getpixel((0, 0)),
        img_rgba.getpixel((img.width - 1, 0)),
        img_rgba.getpixel((0, img.height - 1)),
        img_rgba.getpixel((img.width - 1, img.height - 1))
    ]
    # Average the corner colors
    r = sum(c[0] for c in corners) // 4
    g = sum(c[1] for c in corners) // 4
    b = sum(c[2] for c in corners) // 4
    return (r, g, b)

def rgb_to_hex(rgb):
    """Convert RGB tuple to hex string"""
    return "#{:02x}{:02x}{:02x}".format(rgb[0], rgb[1], rgb[2])

def create_splash_image(icon_path, output_path, size, bg_color, icon_scale=0.5):
    """Create splash image with icon centered on background"""
    # Open original icon
    icon = Image.open(icon_path).convert("RGBA")

    # Create new image with background color
    splash = Image.new("RGBA", (size, size), bg_color + (255,))

    # Calculate icon size (scaled)
    icon_size = int(size * icon_scale)
    icon_resized = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)

    # Calculate position to center icon
    pos = (size - icon_size) // 2

    # Paste icon onto splash (using alpha channel as mask)
    splash.paste(icon_resized, (pos, pos), icon_resized)

    # Save as PNG
    splash.save(output_path, "PNG")
    print(f"✅ Created: {output_path} ({size}x{size})")

def create_android12_icon(icon_path, output_path, size=1152):
    """
    Create Android 12+ splash icon
    - 1152x1152 for icon without background
    - Icon should fit within 768px diameter circle
    """
    icon = Image.open(icon_path).convert("RGBA")

    # Create transparent background
    splash = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Icon should fit within ~66% of total size (768/1152)
    icon_size = int(size * 0.66)
    icon_resized = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)

    # Center the icon
    pos = (size - icon_size) // 2
    splash.paste(icon_resized, (pos, pos), icon_resized)

    splash.save(output_path, "PNG")
    print(f"✅ Created Android 12 icon: {output_path} ({size}x{size})")

def create_android12_icon_with_bg(icon_path, output_path, bg_color, size=960):
    """
    Create Android 12+ splash icon with background
    - 960x960 for icon with background
    - Icon should fit within 640px diameter circle
    """
    icon = Image.open(icon_path).convert("RGBA")

    # Create with background color
    splash = Image.new("RGBA", (size, size), bg_color + (255,))

    # Icon should fit within ~66% of total size (640/960)
    icon_size = int(size * 0.66)
    icon_resized = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)

    # Center the icon
    pos = (size - icon_size) // 2
    splash.paste(icon_resized, (pos, pos), icon_resized)

    splash.save(output_path, "PNG")
    print(f"✅ Created Android 12 icon with bg: {output_path} ({size}x{size})")

def main():
    # Paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)

    icon_path = os.path.join(project_dir, "assets", "icon", "icon.png")
    assets_splash_dir = os.path.join(project_dir, "assets", "splash")

    # Create splash directory if not exists
    os.makedirs(assets_splash_dir, exist_ok=True)

    # Extract background color from icon
    icon = Image.open(icon_path)
    bg_color = get_dominant_corner_color(icon)
    hex_color = rgb_to_hex(bg_color)

    print(f"🎨 Detected background color: {hex_color} (RGB: {bg_color})")
    print()

    # Generate splash images
    print("📱 Generating splash images...")

    # Legacy splash (for Android < 12 and iOS)
    create_splash_image(
        icon_path,
        os.path.join(assets_splash_dir, "splash.png"),
        size=1242,  # 4x for high density
        bg_color=bg_color,
        icon_scale=0.4
    )

    # Android 12+ icon (transparent background - icon only)
    create_android12_icon(
        icon_path,
        os.path.join(assets_splash_dir, "splash_android12.png"),
        size=1152
    )

    # Android 12+ icon with background (for icon_background_color option)
    create_android12_icon_with_bg(
        icon_path,
        os.path.join(assets_splash_dir, "splash_android12_bg.png"),
        bg_color=bg_color,
        size=960
    )

    print()
    print("=" * 50)
    print("📋 Recommended pubspec.yaml configuration:")
    print("=" * 50)
    print(f"""
flutter_native_splash:
  color: "{hex_color}"
  image: assets/splash/splash.png
  android: true
  ios: true

  android_12:
    color: "{hex_color}"
    image: assets/splash/splash_android12.png
    # icon_background_color: "{hex_color}"
""")

if __name__ == "__main__":
    main()
