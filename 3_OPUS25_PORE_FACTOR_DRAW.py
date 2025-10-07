import os
import argparse
from pathlib import Path
from typing import List, Tuple, Dict, Any
from datetime import datetime

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.figure import Figure
from matplotlib.axes import Axes
from matplotlib.backend_bases import MouseEvent, ScrollEvent
from matplotlib.widgets import Button
from PIL import Image
from shapely.geometry import Polygon

# --- Type Hinting for Clarity ---
Point = Tuple[float, float]
ShapeData = Dict[str, Any]

class ManualSegmenter:
    """
    An interactive GUI tool for manually segmenting features in images by
    drawing polygons. It calculates geometric properties for each shape.
    """
    def __init__(self, input_dir: Path, output_dir: Path, resize_factor: float):
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.resize_factor = resize_factor
        
        # Create dedicated subdirectories for clean output
        self.img_output_dir = self.output_dir / "annotated_images"
        self.data_output_dir = self.output_dir / "data"
        self.img_output_dir.mkdir(parents=True, exist_ok=True)
        self.data_output_dir.mkdir(parents=True, exist_ok=True)
        
        supported = ('.png', '.jpg', '.jpeg', '.bmp', '.tif', '.tiff')
        self.image_files = sorted([p for p in input_dir.iterdir() if p.suffix.lower() in supported])

        if not self.image_files:
            raise FileNotFoundError(f"No images found in {input_dir}")
        
        # --- State Management ---
        self.all_shapes_data: List[ShapeData] = [] # Holds data for all images
        self.shapes_on_current_image: List[List[Point]] = [] # Holds polygons for the current image
        self.current_points: List[Point] = [] # Holds vertices for the polygon being drawn
        
        self.current_image_path: Path = None
        self.display_image: np.ndarray = None
        self.fig: Figure = None
        self.ax: Axes = None

    def run(self):
        """Processes each image in the directory interactively."""
        print(f"Found {len(self.image_files)} images. Starting segmentation...")
        for img_path in self.image_files:
            self.current_image_path = img_path
            self._process_image()
        
        self._export_results()
        print("\nAll images processed. Results saved in:", self.output_dir)

    def _process_image(self):
        """Loads a single image and opens the interactive drawing window."""
        self.shapes_on_current_image = []
        self.current_points = []
        
        with Image.open(self.current_image_path) as img:
            w, h = img.size
            new_dims = (int(w * self.resize_factor), int(h * self.resize_factor))
            self.display_image = np.array(img.resize(new_dims))

        self.fig, self.ax = plt.subplots(figsize=(12, 9))
        self.ax.imshow(self.display_image)
        self.ax.set_title(f"Segmenting: {self.current_image_path.name}")
        self.ax.axis('off')

        self._setup_ui()
        plt.show() # Blocks until the window is closed

    def _setup_ui(self):
        """Creates buttons and connects matplotlib events."""
        plt.subplots_adjust(bottom=0.1)
        ax_save = self.fig.add_axes([0.8, 0.01, 0.15, 0.05])
        btn_save = Button(ax_save, 'Save & Next')
        btn_save.on_clicked(self._save_and_close)

        ax_clear = self.fig.add_axes([0.6, 0.01, 0.15, 0.05])
        btn_clear = Button(ax_clear, 'Clear Shapes')
        btn_clear.on_clicked(self._clear_shapes)
        
        self.fig.canvas.mpl_connect('button_press_event', self._on_click)
        self.fig.canvas.mpl_connect('scroll_event', self._on_scroll)

    def _on_click(self, event: MouseEvent):
        """Handles mouse clicks to draw polygons."""
        if event.inaxes != self.ax or event.xdata is None: return

        # Left-click to add a point
        if event.button == 1:
            self.current_points.append((event.xdata, event.ydata))
            self._redraw_canvas()
        
        # Right-click to close a shape
        elif event.button == 3 and len(self.current_points) >= 3:
            self.current_points.append(self.current_points[0]) # Close the loop
            self.shapes_on_current_image.append(list(self.current_points))
            self.current_points = [] # Reset for next shape
            self._redraw_canvas()

    def _clear_shapes(self, event):
        """Callback to clear all drawn shapes on the current image."""
        print("Clearing all shapes from the current image.")
        self.shapes_on_current_image = []
        self.current_points = []
        self._redraw_canvas()

    def _save_and_close(self, event):
        """Callback to save results for the current image and close the window."""
        print(f"Saving {len(self.shapes_on_current_image)} shapes for {self.current_image_path.name}...")
        
        # Calculate properties for all drawn shapes and add to the main data list
        for shape_points in self.shapes_on_current_image:
            polygon = Polygon(shape_points)
            perimeter = polygon.length / self.resize_factor
            area = polygon.area / (self.resize_factor ** 2)
            
            if area > 0:
                pore_factor = (perimeter ** 2) / (16 * area)
                self.all_shapes_data.append({
                    'filename': self.current_image_path.name,
                    'perimeter_px': perimeter,
                    'area_px': area,
                    'pore_factor': pore_factor
                })
        
        # Save the final annotated image
        today_str = datetime.now().strftime('%Y-%m-%d')
        save_img_path = self.img_output_dir / f"{today_str}_{self.current_image_path.stem}.png"
        self.fig.savefig(save_img_path, dpi=300, bbox_inches='tight', pad_inches=0.1)
        print(f"  - Saved annotated image to {save_img_path}")
        
        plt.close(self.fig)

    def _redraw_canvas(self):
        """Clears and redraws the image, completed shapes, and the current drawing."""
        self.ax.clear()
        self.ax.imshow(self.display_image)
        self.ax.set_title(f"Segmenting: {self.current_image_path.name}")
        self.ax.axis('off')

        # Draw completed, filled polygons
        for shape_points in self.shapes_on_current_image:
            xs, ys = zip(*shape_points)
            self.ax.plot(xs, ys, 'r-', linewidth=1.5)
            self.ax.fill(xs, ys, 'r', alpha=0.3)
        
        # Draw the lines for the polygon currently being created
        if self.current_points:
            xs, ys = zip(*self.current_points)
            self.ax.plot(xs, ys, 'ro-', markersize=3, linewidth=1)
        
        self.fig.canvas.draw_idle()

    def _on_scroll(self, event: ScrollEvent):
        """Handles mouse scroll events for zooming."""
        if event.inaxes != self.ax: return
        
        scale_factor = 1.1 if event.button == 'up' else 1 / 1.1
        cur_xlim = self.ax.get_xlim()
        cur_ylim = self.ax.get_ylim()
        xdata, ydata = event.xdata, event.ydata
        
        new_xlim = [
            (cur_xlim[0] - xdata) * scale_factor + xdata,
            (cur_xlim[1] - xdata) * scale_factor + xdata
        ]
        new_ylim = [
            (cur_ylim[0] - ydata) * scale_factor + ydata,
            (cur_ylim[1] - ydata) * scale_factor + ydata
        ]
        self.ax.set_xlim(new_xlim)
        self.ax.set_ylim(new_ylim)
        self.fig.canvas.draw_idle()

    def _export_results(self):
        """Exports all collected data to a single Excel file at the end."""
        if not self.all_shapes_data:
            print("No shapes were drawn to export.")
            return

        today_str = datetime.now().strftime('%Y-%m-%d')
        output_excel_path = self.data_output_dir / f"{today_str}_pore_factor_analysis.xlsx"
        
        df = pd.DataFrame(self.all_shapes_data)
        df.to_excel(output_excel_path, index=False)
        print(f"\nSuccessfully exported all data to {output_excel_path}")


def main():
    parser = argparse.ArgumentParser(description="Manually segment features in images by drawing polygons.")
    parser.add_argument("-i", "--input", type=Path, required=True, help="Input directory with source images.")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output directory to save results.")
    parser.add_argument(
        "-r", "--resize-factor", type=float, default=0.25,
        help="Factor to resize images for display (e.g., 0.25 for 25%%). Default: 0.25"
    )
    args = parser.parse_args()

    try:
        segmenter = ManualSegmenter(args.input, args.output, args.resize_factor)
        segmenter.run()
    except FileNotFoundError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == '__main__':
    main()
