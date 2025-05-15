import os
import matplotlib.pyplot as plt
import numpy as np
import matplotlib.image as mpimg
from PIL import Image
from shapely.geometry import Polygon
import pandas as pd
from datetime import datetime
from scipy.interpolate import splprep, splev

# Initialize variables
points = []
drawing = False
zoom_factor = 1.1  # Zoom factor for each scroll event
shapes_data = []  # To store shape data for export

# Callback function for mouse click events
def on_click(event):
    global points, drawing
    
    # Left mouse click (button 1) - Add point
    if event.button == 1:
        if not drawing:
            points = []  # Reset points if we start drawing
            drawing = True
        points.append((event.xdata, event.ydata))
        plt.plot([p[0] for p in points], [p[1] for p in points], 'r-', markersize=2)
        plt.draw()
        
    # Right mouse click (button 3) - Close shape
    elif event.button == 3 and drawing:
        if len(points) > 1:
            # Closing the shape by drawing the last line
            points.append(points[0])  # Add the first point to close the shape
            plt.plot([p[0] for p in points], [p[1] for p in points], 'r-', markersize=0.2)
            plt.fill([p[0] for p in points], [p[1] for p in points], 'r', alpha=0.2)
            plt.draw()

            # Calculate perimeter and area after the shape is closed
            polygon = Polygon(points)  # Create a polygon from the points
            perimeter = polygon.length  # Calculate perimeter
            area = polygon.area  # Calculate area
            pore_factor = (perimeter**2)/(16*area)  # Calculate pore factor

            # Store shape data for export
            shapes_data.append({
                'filename': current_image_filename,
                'perimeter_px': perimeter,
                'area_px': area,
                'pore_factor': pore_factor
            })
            
            # Save annotated image
            save_img_path = os.path.join('output/image/path', f"{today_str}_{current_image_filename}.png")
            plt.savefig(save_img_path, dpi=300)
            print(f"Saved image with shape to: {save_img_path}")

            # Save updated Excel after each shape
            df = pd.DataFrame(shapes_data)
            df.to_excel(output_excel_path, index=False)
            print(f"Updated Excel saved to: {output_excel_path}")

            drawing = False

# Callback function for zooming with mouse scroll
def zoom(event, ax, img):
    global zoom_factor
    
    # Get the current x and y limits of the plot
    xlim = ax.get_xlim()
    ylim = ax.get_ylim()

    # Get mouse position relative to the image
    mouse_x, mouse_y = event.xdata, event.ydata

    # Check if mouse position is valid (not outside the image)
    if mouse_x is None or mouse_y is None:
        return
    
    # Determine zoom direction (up for zoom in, down for zoom out)
    if event.button == 'up':
        scale_factor = zoom_factor  # Zoom in
    elif event.button == 'down':
        scale_factor = 1 / zoom_factor  # Zoom out
    else:
        return

    # Calculate the new x and y limits based on the mouse position
    new_xlim = [mouse_x - (mouse_x - xlim[0]) * scale_factor,
                mouse_x + (xlim[1] - mouse_x) * scale_factor]
    new_ylim = [mouse_y - (mouse_y - ylim[0]) * scale_factor,
                mouse_y + (ylim[1] - mouse_y) * scale_factor]

    # Apply the new limits
    ax.set_xlim(new_xlim)
    ax.set_ylim(new_ylim)

    # Redraw the plot to update the zoom
    plt.draw()

# Function to display image and handle clicks
def draw_on_image(image_path):
    global zoom_factor, current_image_filename

    # Get the current image filename
    current_image_filename = os.path.basename(image_path)

    # Load the image
    img = Image.open(image_path)

    # Get the original dimensions
    original_width, original_height = img.size

    # Calculate the new dimensions (25% of original size)
    new_width = int(original_width * 0.25)
    new_height = int(original_height * 0.25)

    # Resize the image
    img_resized = img.resize((new_width, new_height))  # Resize to 25% of original size

    # Convert resized image to numpy array
    img_resized = np.array(img_resized)

    fig, ax = plt.subplots()
    ax.imshow(img_resized)
    ax.set_xlim([0, img_resized.shape[1]])
    ax.set_ylim([img_resized.shape[0], 0])  # Flip Y axis to match image coordinates
    ax.set_aspect('equal')  # Maintain aspect ratio
    
    # Connect the click event to the callback function
    cid_click = fig.canvas.mpl_connect('button_press_event', on_click)

    # Connect the scroll event for zooming
    cid_scroll = fig.canvas.mpl_connect('scroll_event', lambda event: zoom(event, ax, img_resized))

    # Show the image and allow drawing
    plt.show()

# Function to read all images from a directory and process them
def read_images_from_directory(directory_path):
    # Get a list of all files in the directory
    files = os.listdir(directory_path)
    
    # Filter out image files (you can extend this list with other formats as needed)
    image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    
    # Loop through all image files
    for image_file in image_files:
        # Construct the full path to the image
        image_path = os.path.join(directory_path, image_file)
        
        # Call the function to display and allow drawing on the image
        print(f"Processing image: {image_file}")
        draw_on_image(image_path)

# Function to export data to Excel
def export_to_excel(output_path):
    # Create a DataFrame from the collected shape data
    df = pd.DataFrame(shapes_data)
    
    # Export to Excel
    df.to_excel(output_path, index=False)
    print(f"Data has been exported to {output_path}")

# Path to the directory containing images
directory_path = 'input/image/path'  # Replace with your directory

# Generate today's date in the format YYYY_MM_DD
today_str = datetime.now().strftime('%Y_%m_%d')

# Construct the output file path with date in filename
output_excel_path = f'output/excel/path/{today_str}_pore_factor.xlsx'


# Call the function to read and process images
read_images_from_directory(directory_path)

# After processing all images, export the collected data to Excel
export_to_excel(output_excel_path)
