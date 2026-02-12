import os
import textwrap
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Configuration
OUTPUT_WIDTH = 1290
OUTPUT_HEIGHT = 2796
FRAME_PADDING = 100
DEVICE_BORDER_RADIUS = 140
DEVICE_BORDER_COLOR = (30, 30, 30)
DEVICE_BORDER_WIDTH = 25
SCREEN_CONTENT_PADDING = 20

# Layout
TITLE_Y = 250
SUBTITLE_Y_OFFSET = 180 # Distance from title start
DEVICE_Y = 700

# Fonts
# Attempting to use AppleSDGothicNeo. If not found, will fall back.
FONT_PATH = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
TITLE_FONT_SIZE = 110
SUBTITLE_FONT_SIZE = 70

SCENES = [
    {
        "name": "promo_hero_kr_v2",
        "bg_colors": [(0, 255, 255), (255, 220, 0)], # Cyan -> Golden Yellow
        "title": "터치 한 번으로\n와이파이 찾기! 🎉",
        "subtitle": "내 주변 무료 와이파이 즉시 검색",
        "screenshot": "screenshots/en/screentshot_appstore_eng.png", 
    },
    {
        "name": "promo_coverage_kr_v2",
        "bg_colors": [(140, 0, 255), (255, 100, 200)], # Vivid Purple -> Pink
        "title": "서울부터 부산까지\n전국 어디서나 📡",
        "subtitle": "데이터 걱정 없이 마음껏!",
        "screenshot": "screenshots/ko/screenshot_appstore_6.7_클러스터링.png",
    },
    {
        "name": "promo_benefit_kr_v2",
        "bg_colors": [(0, 50, 150), (0, 200, 200)], # Navy -> Teal
        "title": "여행 필수품!\n끊김 없는 여행 ✈️",
        "subtitle": "복잡한 로그인 없이 바로 연결",
        "screenshot": "screenshots/ko/screenshot_appstore_6.7_마커클릭.png",
    },
    {
        "name": "promo_free_kr_v2",
        "bg_colors": [(0, 200, 80), (0, 128, 255)], # Green -> Blue
        "title": "100% 무료!\n로그인 필요 없음 🆓",
        "subtitle": "개인정보 걱정 없이 바로 사용",
        "screenshot": None, # No screenshot for this page
    }
]

def create_gradient(width, height, start_color, end_color):
    base = Image.new('RGB', (width, height), start_color)
    top = Image.new('RGB', (width, height), end_color)
    mask = Image.new('L', (width, height))
    mask_data = []
    
    # Simple linear gradient usually looks boring. Let's make it radial-ish or diagonal
    # Actually diagonal linear is easy and looks okay.
    for y in range(height):
        for x in range(width):
            # Diagonal gradient top-left to bottom-right
            ratio = (x + y) / (width + height)
            mask_data.append(int(255 * ratio))
            
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    return base

def draw_text_centered(draw, width, text, y, font, fill="white", stroke=True):
    lines = text.split('\n')
    current_y = y
    
    for line in lines:
        left, top, right, bottom = draw.textbbox((0, 0), line, font=font)
        w = right - left
        h = bottom - top
        x = (width - w) / 2
        
        if stroke:
            # Thick outer stroke for pop effect
            stroke_width = 5
            draw.text((x, current_y), line, font=font, fill=fill, stroke_width=stroke_width, stroke_fill="black")
        else:
            draw.text((x, current_y), line, font=font, fill=fill)
            
        current_y += h + 20 # Line spacing

def add_device_frame(bg_image, screenshot_path):
    if not os.path.exists(screenshot_path):
        print(f"Screenshot not found: {screenshot_path}")
        return

    try:
        screenshot = Image.open(screenshot_path).convert("RGBA")
    except Exception as e:
        print(f"Error opening screenshot: {e}")
        return

    # Resize screenshot to reasonable width (85% of output width)
    target_ss_width = int(OUTPUT_WIDTH * 0.82)
    ratio = target_ss_width / screenshot.width
    target_ss_height = int(screenshot.height * ratio)
    
    # High quality resize
    screenshot = screenshot.resize((target_ss_width, target_ss_height), Image.Resampling.LANCZOS)

    # 1. Create Frame Container
    frame_width = target_ss_width + DEVICE_BORDER_WIDTH * 2
    frame_height = target_ss_height + DEVICE_BORDER_WIDTH * 2
    
    frame_img = Image.new("RGBA", (frame_width, frame_height), (0,0,0,0))
    draw_frame = ImageDraw.Draw(frame_img)
    
    # 2. Draw Main Body (Dark Grey/Black)
    draw_frame.rounded_rectangle(
        (0, 0, frame_width, frame_height), 
        radius=DEVICE_BORDER_RADIUS, 
        fill=DEVICE_BORDER_COLOR
    )

    # 3. Create Mask for Screen Content (Rounded Corners in screen)
    # Screen radius should be slightly smaller than device radius
    screen_radius = DEVICE_BORDER_RADIUS - DEVICE_BORDER_WIDTH
    mask = Image.new("L", (target_ss_width, target_ss_height), 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.rounded_rectangle((0, 0, target_ss_width, target_ss_height), radius=screen_radius, fill=255)
    
    # 4. Composite Screen Content
    screen_layer = Image.new("RGBA", (target_ss_width, target_ss_height))
    screen_layer.paste(screenshot, (0, 0), mask)
    
    # 5. Paste Screen onto Frame
    frame_img.paste(screen_layer, (DEVICE_BORDER_WIDTH, DEVICE_BORDER_WIDTH), screen_layer)
    
    # 6. Add Notch (Dynamic Island style)
    notch_width = int(target_ss_width * 0.35)
    notch_height = 90
    notch_x = (frame_width - notch_width) // 2
    notch_y = DEVICE_BORDER_WIDTH + 20
    draw_frame.rounded_rectangle(
        (notch_x, notch_y, notch_x + notch_width, notch_y + notch_height),
        radius=45,
        fill="black"
    )

    # 7. Add Drop Shadow to the whole phone
    # Make shadow canvas larger
    shadow_offset = 60
    shadow_blur = 50
    shadow_canvas = Image.new("RGBA", (frame_width + shadow_offset*2, frame_height + shadow_offset*2), (0,0,0,0))
    draw_shadow = ImageDraw.Draw(shadow_canvas)
    
    # Draw shadow rectangle
    draw_shadow.rounded_rectangle(
        (shadow_offset, shadow_offset + 20, shadow_offset + frame_width, shadow_offset + frame_height + 20),
        radius=DEVICE_BORDER_RADIUS,
        fill=(0, 0, 0, 120)
    )
    # Blur shadow
    shadow_canvas = shadow_canvas.filter(ImageFilter.GaussianBlur(shadow_blur))
    
    # 8. Composite Frame onto Shadow
    shadow_canvas.paste(frame_img, (shadow_offset, shadow_offset), frame_img)
    
    # 9. Paste Final Phone (Shadow + Frame) onto Background
    # Center horizontally
    final_x = (OUTPUT_WIDTH - shadow_canvas.width) // 2
    # Vertical position
    final_y = DEVICE_Y
    
    bg_image.paste(shadow_canvas, (final_x, final_y), shadow_canvas)

def generate():
    os.makedirs("screenshots/promo", exist_ok=True)
    
    # Load Font
    try:
        # Index 8 usually Heavy/Black, 6 Bold. Let's try to be safe with 6 or 4.
        # Check if index 8 exists, otherwise try default.
        font_title = ImageFont.truetype(FONT_PATH, TITLE_FONT_SIZE, index=8)
        font_sub = ImageFont.truetype(FONT_PATH, SUBTITLE_FONT_SIZE, index=6)
    except Exception as e:
        print(f"Font loading failed: {e}. Falling back to default.")
        font_title = ImageFont.load_default(size=TITLE_FONT_SIZE)
        font_sub = ImageFont.load_default(size=SUBTITLE_FONT_SIZE)

    for scene in SCENES:
        print(f"Generating {scene['name']}...")
        
        # 1. Background
        img = create_gradient(OUTPUT_WIDTH, OUTPUT_HEIGHT, scene["bg_colors"][0], scene["bg_colors"][1])
        draw = ImageDraw.Draw(img)
        
        # 2. Device OR Icon
        screenshot_path = scene.get("screenshot")
        if screenshot_path and os.path.exists(screenshot_path):
            add_device_frame(img, screenshot_path)
            # Text at top
            draw_text_centered(draw, OUTPUT_WIDTH, scene["title"], TITLE_Y, font_title)
            subtitle_y = TITLE_Y + (TITLE_FONT_SIZE * (scene["title"].count('\n') + 1)) + 60
            draw_text_centered(draw, OUTPUT_WIDTH, scene["subtitle"], subtitle_y, font_sub)
        else:
            # Layout for No Screenshot page (Centered Text + Large Icon)
            # Draw Text Centered in upper-middle
            total_height = OUTPUT_HEIGHT
            
            # Title
            draw_text_centered(draw, OUTPUT_WIDTH, scene["title"], total_height // 2 - 400, font_title)
            
            # Subtitle
            subtitle_y = total_height // 2 - 400 + (TITLE_FONT_SIZE * (scene["title"].count('\n') + 1)) + 60
            draw_text_centered(draw, OUTPUT_WIDTH, scene["subtitle"], subtitle_y, font_sub)
            
            # Draw Large Emoji/Icon below
            try:
                # Attempt to use a large font for emoji if possible, or just draw a circle
                # Mac system font AppleColorEmoji might work but it's tricky with PIL.
                # Let's just draw a large stylized text or circle for now as placeholder
                icon_text = "🔒" # Default lock
                font_icon = ImageFont.truetype("/System/Library/Fonts/Apple Color Emoji.ttc", 500) # This often fails in PIL standard
                # Keeping it simple: Draw a large circle and text inside if simpler
                # Or just use the text drawing which might render B&W emoji
            except:
                pass
            
            # Fallback simple graphic for "No Login" -> A Shield/Lock shape
            cx, cy = OUTPUT_WIDTH // 2, OUTPUT_HEIGHT // 2 + 300
            r = 300
            draw.ellipse((cx-r, cy-r, cx+r, cy+r), fill=(255,255,255,50), outline="white", width=20)
            
            # Draw "FREE" text inside
            draw.text((cx-180, cy-100), "FREE", font=font_title, fill="white")


        output_path = f"screenshots/promo/{scene['name']}.png"
        img.save(output_path)
        print(f"Saved {output_path}")

if __name__ == "__main__":
    generate()
