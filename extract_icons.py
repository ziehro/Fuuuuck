# extract_icons.py
import cv2
import numpy as np
from pathlib import Path

# Grid configurations
GRIDS = {
    'shells_grid.png': [
        ['butter_clam', 'mussel', 'crab', 'oyster', 'whelks'],
        ['turban', 'sand_dollars', 'cockles', 'starfish', 'which_shells']
    ],
    'beach_materials_grid.png': [
        ['sand', 'pebbles', 'baseball_rocks', 'rocks', 'boulders'],
        ['stone', 'coal', 'mud', 'midden', 'islands']
    ],
    'marine_life_grid.png': [
        ['seaweed_beach', 'seaweed_rocks', 'kelp_beach', 'anemones', 'barnacles'],
        ['bugs', 'snails', 'oysters_living', 'clams_living', 'limpets_living']
    ],
    'wood_trees_grid.png': [
        ['kindling', 'firewood', 'logs', 'trees', 'tree_types'],
        ['turtles', 'mussels_living', 'birds', 'garbage', 'people']
    ],
    'beach_features_grid.png': [
        ['width', 'length', 'bluff_height', 'bluffs_grade', 'boats_on_shore'],
        ['caves', 'lookout', 'patio_nearby', 'gold', 'private']
    ],
    'conditions_grid.png': [
        ['stink', 'windy', 'shape', 'bluff_comp', 'rock_type'],
        ['best_tide', 'parking', 'treasure', 'new_items', 'man_made']
    ],
    'shade_grid.png': [
        ['shade']
    ]
}

def detect_white_circle(img, cell_x, cell_y, cell_w, cell_h):
    """Detect white circle boundaries in a cell."""
    cell = img[cell_y:cell_y+cell_h, cell_x:cell_x+cell_w]
    
    # Convert to grayscale
    gray = cv2.cvtColor(cell, cv2.COLOR_BGR2GRAY)

    # Create mask for white pixels (threshold > 240)
    _, mask = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY)

    # Find contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if not contours:
        return None

    # Get bounding box of largest contour
    largest = max(contours, key=cv2.contourArea)
    x, y, w, h = cv2.boundingRect(largest)

    # Calculate circle center and radius
    center_x = cell_x + x + w // 2
    center_y = cell_y + y + h // 2
    radius = min(w, h) // 2

    # Apply adjustments - tighter crop
    adjusted_radius = int(radius * 0.88)  # Slightly larger than before
    adjusted_center_y = center_y - int(radius * 0.10)  # Less shift

    return center_x, adjusted_center_y, adjusted_radius

def extract_circular_icon(img, center_x, center_y, radius):
    """Extract circular portion with transparent background."""
    size = radius * 2
    x = max(0, center_x - radius)
    y = max(0, center_y - radius)

    # Handle edge cases
    x_end = min(img.shape[1], x + size)
    y_end = min(img.shape[0], y + size)

    actual_w = x_end - x
    actual_h = y_end - y

    # Extract square region
    cropped = img[y:y_end, x:x_end].copy()

    # Create result with proper size
    result = np.zeros((size, size, 4), dtype=np.uint8)

    # Create circular mask
    mask = np.zeros((size, size), dtype=np.uint8)
    cv2.circle(mask, (radius, radius), radius, 255, -1)

    # Apply feathering to smooth edges
    mask = cv2.GaussianBlur(mask, (5, 5), 0)

    # Place cropped content
    result[0:actual_h, 0:actual_w, 0:3] = cropped
    result[0:actual_h, 0:actual_w, 3] = mask[0:actual_h, 0:actual_w]

    # Remove checkered background by replacing light pixels with transparency
    gray_result = cv2.cvtColor(result[:, :, 0:3], cv2.COLOR_BGR2GRAY)

    # Create alpha based on whether pixel is part of white background
    # Keep pixels that are NOT white/light gray
    light_mask = gray_result < 240  # Keep pixels darker than 240
    result[:, :, 3] = np.where(light_mask, result[:, :, 3], 0)

    return result

def process_grid(grid_file, icon_names, output_dir):
    """Process a single grid file."""
    print(f"\n📋 Processing {grid_file}...")

    img = cv2.imread(grid_file)
    if img is None:
        print(f"❌ Could not load {grid_file}")
        return

    height, width = img.shape[:2]

    # Determine grid dimensions
    num_rows = len(icon_names)
    num_cols = max(len(row) for row in icon_names)

    cell_width = width // num_cols
    cell_height = height // num_rows

    extracted_count = 0

    for row_idx, row in enumerate(icon_names):
        for col_idx, icon_name in enumerate(row):
            if not icon_name:
                continue

            cell_x = col_idx * cell_width
            cell_y = row_idx * cell_height

            # Detect circle
            circle_info = detect_white_circle(img, cell_x, cell_y, cell_width, cell_height)

            if circle_info is None:
                print(f"  ⚠️  No circle found for {icon_name}")
                continue

            center_x, center_y, radius = circle_info

            # Extract icon
            icon_img = extract_circular_icon(img, center_x, center_y, radius)

            # Save
            output_path = output_dir / f"{icon_name}.png"
            cv2.imwrite(str(output_path), icon_img)

            extracted_count += 1
            print(f"  ✅ {icon_name}.png (center: {center_x}, {center_y}, radius: {radius})")
    
    print(f"✨ Extracted {extracted_count} icons from {grid_file}")

def main():
    # Create output directory
    output_dir = Path("assets/icons")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("🎨 Beach Icon Extractor")
    print("=" * 50)
    
    total_icons = 0
    
    for grid_file, icon_layout in GRIDS.items():
        grid_path = Path("assets") / grid_file
        
        if not grid_path.exists():
            print(f"\n⚠️  Skipping {grid_file} (not found)")
            continue
        
        process_grid(str(grid_path), icon_layout, output_dir)
        total_icons += sum(len(row) for row in icon_layout)
    
    print("\n" + "=" * 50)
    print(f"🎉 Complete! Extracted icons for {total_icons} items")
    print(f"📁 Output directory: {output_dir.absolute()}")

if __name__ == "__main__":
    main()