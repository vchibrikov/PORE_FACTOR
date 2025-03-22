import cv2
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider
import os
import pandas as pd

# Define the directory and get a list of images
directory_path = "path/to/input/files"

# Get a list of image files
image_files = [f for f in os.listdir(directory_path) if f.lower().endswith(('.jpeg', '.jpg', '.png', '.bmp'))]

if not image_files:
    print("No images found in the directory.")
    exit()

# Create output directory if not exists
output_dir = "path/to/output/files"
os.makedirs(output_dir, exist_ok=True)

# Initial parameters
canny_lower_threshold =  # Initial lower threshold for Canny edge detection
canny_upper_threshold =  # Initial upper threshold for Canny edge detection
min_edge_size =   # Initial minimum edge size
circularity_threshold =   # Initial circularity threshold
kernel_size =   # Initial dilation kernel size
gaussian_kernel_size =   # Initial Gaussian kernel size
median_kernel_size =   # Initial median kernel size
epsilon_value =  # Initial epsilon for approxPolyDP
binary_threshold_value =  # Initial binary threshold value

# Parameter boundaries
canny_lower_boundary, canny_upper_boundary = # Define Canny threshold boundaries
min_edge_boundary, max_edge_boundary = # Define min and max edge size boundaries
circularity_min, circularity_max = # Define circularity boundaries
kernel_min, kernel_max = # Define dilation kernel size boundaries
blur_min, blur_max =   # Must be odd for Gaussian & median blurs
epsilon_min, epsilon_max =   # Define epsilon range for dynamic adjustment
binary_threshold_min, binary_threshold_max =   # Range for binary threshold slider

def process_image(image, lower_threshold, upper_threshold, min_size, min_circularity, kernel_size, g_kernel, m_kernel, epsilon, binary_threshold):
    """Apply Gaussian and median blurs, Canny edge detection, binary threshold, and filter by size and circularity."""
    # Ensure odd kernel sizes
    g_kernel = max(3, int(g_kernel) | 1)
    m_kernel = max(3, int(m_kernel) | 1)

    # Apply Gaussian and median blurs
    blurred_image = cv2.GaussianBlur(image, (g_kernel, g_kernel), 0) # Apply Gaussian blur
    blurred_image = cv2.medianBlur(blurred_image, m_kernel) # Apply median blur

    # Edge detection
    edges = cv2.Canny(blurred_image, int(lower_threshold), int(upper_threshold)) # Apply Canny edge detection

    # Apply binary thresholding
    _, binary_image = cv2.threshold(edges, binary_threshold, 255, cv2.THRESH_BINARY) # Apply binary threshold

    # Define dynamic dilation kernel
    kernel_size = max(3, int(kernel_size) | 1)  # Ensure odd size
    dilation_kernel = np.ones((kernel_size, kernel_size), np.uint8) # Create dilation kernel

    # Dilate edges
    thick_edges = cv2.dilate(binary_image, dilation_kernel, iterations=1) # Dilate edges

    # Find contours
    contours, _ = cv2.findContours(thick_edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE) # Find contours

    # Create a blank image to store filtered edges
    filtered_edges = np.zeros_like(thick_edges) # Blank image to store filtered edges
    object_data = []

    # Filter by area and circularity
    for contour in contours:
        # Approximate contour to polygon with dynamic epsilon value
        epsilon_dynamic = epsilon * cv2.arcLength(contour, True)  # Dynamic epsilon based on slider value
        approx_contour = cv2.approxPolyDP(contour, epsilon_dynamic, True) # Approximate contour

        area = cv2.contourArea(approx_contour) # Calculate area
        perimeter = cv2.arcLength(approx_contour, True) # Calculate perimeter

        # Check for zero area to avoid division by zero
        if area == 0:
            continue  # Skip this contour if the area is zero

        pore_factor = (perimeter**2) / (16 * area)  # Calculate pore factor

        circularity = (4 * np.pi * area) / (perimeter ** 2)  # Circularity formula
        if area > min_size and circularity >= min_circularity:
            cv2.drawContours(filtered_edges, [approx_contour], -1, 255, thickness=cv2.FILLED) # Draw filled contour
            object_data.append((perimeter, area, pore_factor)) # Store object data

    return filtered_edges, object_data


def save_results(image_file, edges, object_data):
    """Save processed image and object data."""
    base_name = os.path.splitext(image_file)[0]
    save_path = os.path.join(output_dir, f"{base_name}_processed.png")
    cv2.imwrite(save_path, edges) # Save the processed image
    print(f"Saved: {save_path}")

    # Save data to Excel
    excel_path = os.path.join(output_dir, f"{base_name}.xlsx")
    df = pd.DataFrame(object_data, columns=["perimeter_px", "area_px", "pore_factor"]) 
    df.insert(0, "filename", image_file)
    df.to_excel(excel_path, index=False) # Save data to Excel
    print(f"Saved data: {excel_path}")

# Function to update dynamically
def update(val):
    lower_threshold = slider_lower.val # Get lower threshold value from slider
    upper_threshold = slider_upper.val # Get upper threshold value from slider
    current_min_size = int(slider_min_size.val) # Get min edge size value from slider
    current_circularity = slider_circularity.val # Get circularity value from slider
    current_kernel_size = int(slider_kernel_size.val) # Get kernel size value from slider
    current_g_kernel = int(slider_gaussian.val) # Get Gaussian kernel value from slider
    current_m_kernel = int(slider_median.val) # Get median kernel value from slider
    current_epsilon = slider_epsilon.val  # Get dynamic epsilon value from slider
    current_binary_threshold = slider_binary_threshold.val  # Get binary threshold value from slider

    # Process the image with updated parameters
    edges, object_data = process_image(image, lower_threshold, upper_threshold, current_min_size, current_circularity, current_kernel_size, current_g_kernel, current_m_kernel, current_epsilon, current_binary_threshold)

    ax.clear()
    ax.imshow(edges, cmap='gray') # Display the updated image
    ax.axis('off')
    fig.canvas.draw_idle()

    # Save the updated image
    save_results(image_file, edges, object_data)

# Create figure and axis
fig, ax = plt.subplots(figsize=(16, 12)) # Set figure size
plt.subplots_adjust(bottom=0.3)  # Adjust for additional sliders

# Loop through all image files
for image_file in image_files:
    image_path = os.path.join(directory_path, image_file)

    # Load the image in grayscale
    image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE) # Load image in grayscale

    if image is None:
        print(f"Failed to load image: {image_path}")
        continue

    # Initial processing
    edges, object_data = process_image(image, canny_lower_threshold, canny_upper_threshold, min_edge_size, circularity_threshold, kernel_size, gaussian_kernel_size, median_kernel_size, epsilon_value, binary_threshold_value)

    ax.imshow(edges, cmap='gray')
    ax.axis('off')

    # Save the initial processed image
    save_results(image_file, edges, object_data) # Save the initial processed image

    # Create slider axes
    ax_slider_lower = plt.axes([0.2, 0.16, 0.65, 0.03]) # Define slider position
    ax_slider_upper = plt.axes([0.2, 0.13, 0.65, 0.03])
    ax_slider_min_size = plt.axes([0.2, 0.1, 0.65, 0.03])
    ax_slider_circularity = plt.axes([0.2, 0.19, 0.65, 0.03])
    ax_slider_kernel_size = plt.axes([0.2, 0.07, 0.65, 0.03])
    ax_slider_gaussian = plt.axes([0.2, 0.04, 0.65, 0.03])
    ax_slider_median = plt.axes([0.2, 0.01, 0.65, 0.03])
    ax_slider_epsilon = plt.axes([0.2, 0.22, 0.65, 0.03]) 
    ax_slider_binary_threshold = plt.axes([0.2, 0.25, 0.65, 0.03])

    # Create sliders
    slider_lower = Slider(ax_slider_lower, 'Canny Lower Threshold', canny_lower_boundary, canny_upper_boundary, valinit=canny_lower_threshold, valstep=1) # Lower threshold slider
    slider_upper = Slider(ax_slider_upper, 'Canny Upper Threshold', canny_lower_boundary, canny_upper_boundary, valinit=canny_upper_threshold, valstep=1) # Upper threshold slider
    slider_min_size = Slider(ax_slider_min_size, 'Min Edge Size', min_edge_boundary, max_edge_boundary, valinit=min_edge_size, valstep=1) # Min edge size slider
    slider_circularity = Slider(ax_slider_circularity, 'Circularity', circularity_min, circularity_max, valinit=circularity_threshold, valstep=0.001) # Circularity slider
    slider_kernel_size = Slider(ax_slider_kernel_size, 'Dilation Kernel', kernel_min, kernel_max, valinit=kernel_size, valstep=2) # Kernel size slider
    slider_gaussian = Slider(ax_slider_gaussian, 'Gaussian Blur', blur_min, blur_max, valinit=gaussian_kernel_size, valstep=2) # Gaussian blur slider
    slider_median = Slider(ax_slider_median, 'Median Blur', blur_min, blur_max, valinit=median_kernel_size, valstep=2) # Median blur slider
    slider_epsilon = Slider(ax_slider_epsilon, 'Epsilon (Approximation)', epsilon_min, epsilon_max, valinit=epsilon_value, valstep=0.0001)  # Epsilon slider
    slider_binary_threshold = Slider(ax_slider_binary_threshold, 'Binary Threshold', binary_threshold_min, binary_threshold_max, valinit=binary_threshold_value, valstep=1)  # Binary threshold slider

    # Attach update function to sliders
    slider_lower.on_changed(update) # Lower threshold update
    slider_upper.on_changed(update) # Upper threshold update
    slider_min_size.on_changed(update) # Min edge size update
    slider_circularity.on_changed(update) # Circularity update
    slider_kernel_size.on_changed(update) # Kernel size update
    slider_gaussian.on_changed(update) # Gaussian blur update
    slider_median.on_changed(update) # Median blur update
    slider_epsilon.on_changed(update)  # Epsilon update
    slider_binary_threshold.on_changed(update)  # Binary threshold update

    plt.show()  # Display the image with sliders
