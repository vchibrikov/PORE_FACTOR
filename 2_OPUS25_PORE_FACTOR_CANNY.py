import os
import argparse
from pathlib import Path
from typing import List, Tuple, Dict, Any

import cv2
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button

class PoreAnalyzer:
    """
    An interactive GUI tool for analyzing pore-like structures in images.

    This tool provides a multi-parameter image processing pipeline to isolate
    features (pores) based on their size and circularity. Users can adjust
    all parameters with real-time visual feedback and save the results for
    each image in a batch.
    """
    def __init__(self, input_dir: Path, output_dir: Path, params: Dict[str, Any]):
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.params = params
        
        # Create a dedicated subdirectory for images and data
        self.img_output_dir = self.output_dir / "processed_images"
        self.data_output_dir = self.output_dir / "data"
        self.img_output_dir.mkdir(parents=True, exist_ok=True)
        self.data_output_dir.mkdir(parents=True, exist_ok=True)
        
        supported = ('.png', '.jpg', '.jpeg', '.bmp', '.tif', '.tiff')
        self.image_files = sorted([p for p in input_dir.iterdir() if p.suffix.lower() in supported])

        if not self.image_files:
            raise FileNotFoundError(f"No images found in {input_dir}")
        
        # --- State for the current image ---
        self.current_image_path: Path = None
        self.original_image: np.ndarray = None
        self.processed_image: np.ndarray = None
        self.object_data: List[Tuple] = []
        self.fig = None
        self.ax = None
        self.sliders: Dict[str, Slider] = {}

    def run(self):
        """Processes each image in the directory interactively."""
        print(f"Found {len(self.image_files)} images. Starting analysis...")
        for img_path in self.image_files:
            self.current_image_path = img_path
            self.original_image = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
            if self.original_image is None:
                print(f"Warning: Could not read {img_path.name}. Skipping.")
                continue
            
            self._create_interactive_window()
        print("\nAll images processed. Results saved in:", self.output_dir)

    def _create_interactive_window(self):
        """Sets up the Matplotlib window with sliders and a button for one image."""
        self.fig, self.ax = plt.subplots(figsize=(12, 9))
        plt.subplots_adjust(bottom=0.4)
        self.ax.set_title(f"Analyzing: {self.current_image_path.name}")
        
        self._create_widgets()
        self._update_plot() # Initial processing and display
        plt.show() # Blocks until the window is closed

    def _update_plot(self, val=None):
        """Gathers slider values, processes the image, and updates the plot."""
        current_params = {name: slider.val for name, slider in self.sliders.items()}
        
        self.processed_image, self.object_data = self._process_image(current_params)
        
        self.ax.clear()
        self.ax.imshow(self.processed_image, cmap='gray')
        self.ax.set_title(f"Analyzing: {self.current_image_path.name} | Found: {len(self.object_data)} objects")
        self.ax.axis('off')
        self.fig.canvas.draw_idle()

    def _process_image(self, p: Dict[str, Any]) -> Tuple[np.ndarray, List]:
        """Core image processing pipeline."""
        # Ensure odd kernel sizes for blurs and dilation
        g_k = max(3, int(p['gaussian_k']) | 1)
        m_k = max(3, int(p['median_k']) | 1)
        d_k = max(3, int(p['dilation_k']) | 1)
        
        blurred = cv2.GaussianBlur(self.original_image, (g_k, g_k), 0)
        blurred = cv2.medianBlur(blurred, m_k)
        
        edges = cv2.Canny(blurred, int(p['canny_low']), int(p['canny_high']))
        _, binary = cv2.threshold(edges, p['binary_thresh'], 255, cv2.THRESH_BINARY)
        
        dilation_kernel = np.ones((d_k, d_k), np.uint8)
        dilated = cv2.dilate(binary, dilation_kernel, iterations=1)
        
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        filtered_image = np.zeros_like(dilated)
        object_data = []
        
        for cnt in contours:
            perimeter = cv2.arcLength(cnt, True)
            if perimeter == 0: continue

            epsilon = p['epsilon'] * perimeter
            approx = cv2.approxPolyDP(cnt, epsilon, True)
            
            area = cv2.contourArea(approx)
            if area == 0: continue
            
            perimeter = cv2.arcLength(approx, True) # Recalculate for approximated shape
            if perimeter == 0: continue

            circularity = (4 * np.pi * area) / (perimeter ** 2)
            
            if area > p['min_area'] and circularity >= p['min_circ']:
                cv2.drawContours(filtered_image, [approx], -1, 255, thickness=cv2.FILLED)
                # Pore Factor = P^2 / (16 * A)
                pore_factor = (perimeter ** 2) / (16 * area) if area > 0 else 0
                object_data.append((perimeter, area, circularity, pore_factor))

        return filtered_image, object_data

    def _save_and_close(self, event):
        """Saves results and closes the current window to proceed."""
        print(f"Saving results for {self.current_image_path.name}...")
        base_name = self.current_image_path.stem
        
        # Save processed image
        save_path_img = self.img_output_dir / f"{base_name}_processed.png"
        cv2.imwrite(str(save_path_img), self.processed_image)
        print(f"  - Saved image to {save_path_img}")
        
        # Save data to Excel
        if self.object_data:
            df = pd.DataFrame(self.object_data, columns=["perimeter_px", "area_px", "circularity", "pore_factor"])
            df.insert(0, "filename", self.current_image_path.name)
            save_path_excel = self.data_output_dir / f"{base_name}_data.xlsx"
            df.to_excel(save_path_excel, index=False)
            print(f"  - Saved data to {save_path_excel}")
        else:
            print("  - No objects found to save.")
            
        plt.close(self.fig)

    def _create_widgets(self):
        """Creates and lays out all the sliders and the button."""
        widget_color = 'lightgoldenrodyellow'
        
        # Define positions for 9 sliders and 1 button
        ax_bt = plt.axes([0.25, 0.32, 0.6, 0.022], facecolor=widget_color)
        ax_cl = plt.axes([0.25, 0.29, 0.6, 0.022], facecolor=widget_color)
        ax_ch = plt.axes([0.25, 0.26, 0.6, 0.022], facecolor=widget_color)
        ax_ep = plt.axes([0.25, 0.23, 0.6, 0.022], facecolor=widget_color)
        ax_cr = plt.axes([0.25, 0.20, 0.6, 0.022], facecolor=widget_color)
        ax_ar = plt.axes([0.25, 0.17, 0.6, 0.022], facecolor=widget_color)
        ax_dk = plt.axes([0.25, 0.14, 0.6, 0.022], facecolor=widget_color)
        ax_gk = plt.axes([0.25, 0.11, 0.6, 0.022], facecolor=widget_color)
        ax_mk = plt.axes([0.25, 0.08, 0.6, 0.022], facecolor=widget_color)
        ax_btn = plt.axes([0.8, 0.9, 0.1, 0.04])

        # Create widgets
        self.sliders['binary_thresh'] = Slider(ax_bt, 'Binary Threshold', 0, 255, valinit=self.params['binary_thresh'], valstep=1)
        self.sliders['canny_low'] = Slider(ax_cl, 'Canny Low', 0, 255, valinit=self.params['canny_low'], valstep=1)
        self.sliders['canny_high'] = Slider(ax_ch, 'Canny High', 0, 255, valinit=self.params['canny_high'], valstep=1)
        self.sliders['epsilon'] = Slider(ax_ep, 'Approximation ε', 0.0001, 0.05, valinit=self.params['epsilon'], valfmt='%0.4f')
        self.sliders['min_circ'] = Slider(ax_cr, 'Min Circularity', 0.0, 1.0, valinit=self.params['min_circ'], valfmt='%0.3f')
        self.sliders['min_area'] = Slider(ax_ar, 'Min Area', 0, 100000, valinit=self.params['min_area'], valstep=100)
        self.sliders['dilation_k'] = Slider(ax_dk, 'Dilation Kernel', 1, 111, valinit=self.params['dilation_k'], valstep=2)
        self.sliders['gaussian_k'] = Slider(ax_gk, 'Gaussian Kernel', 1, 201, valinit=self.params['gaussian_k'], valstep=2)
        self.sliders['median_k'] = Slider(ax_mk, 'Median Kernel', 1, 201, valinit=self.params['median_k'], valstep=2)
        self.button = Button(ax_btn, 'Save & Next')

        # Connect events
        for slider in self.sliders.values():
            slider.on_changed(self._update_plot)
        self.button.on_clicked(self._save_and_close)


def main():
    parser = argparse.ArgumentParser(description="Interactively analyze pores in images.")
    parser.add_argument("-i", "--input", type=Path, required=True, help="Input directory with source images.")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output directory to save results.")
    
    # Add arguments for all initial parameters
    parser.add_argument("--canny-low", type=int, default=10)
    parser.add_argument("--canny-high", type=int, default=50)
    parser.add_argument("--min-area", type=int, default=25000)
    parser.add_argument("--min-circ", type=float, default=0.001)
    parser.add_argument("--dilation-k", type=int, default=3)
    parser.add_argument("--gaussian-k", type=int, default=5)
    parser.add_argument("--median-k", type=int, default=5)
    parser.add_argument("--epsilon", type=float, default=0.01)
    parser.add_argument("--binary-thresh", type=int, default=128)
    args = parser.parse_args()

    params = {k: v for k, v in vars(args).items() if k not in ['input', 'output']}
    
    try:
        analyzer = PoreAnalyzer(args.input, args.output, params)
        analyzer.run()
    except FileNotFoundError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == '__main__':
    main()
