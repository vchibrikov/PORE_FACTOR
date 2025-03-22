# PORE_FACTOR
- Current repository provides an image processing script that performs edge detection, object filtering, and calculates the pore factor of detected objects. 
- Repository is created for the project entitled "Printing of 3D biomaterials inspired by plant cell wall", supported by the National Science Centre, Poland (grant nr - 2023/49/B/NZ9/02979).
- Research methodology is an automative approach reported in papers:

Merli, M., Sardelli, L., Baranzini, N., Grimaldi, A., Jacchetti, E., Raimondi, M. T., ... & Tunesi, M. (2022). Pectin-based bioinks for 3D models of neural tissue produced by a pH-controlled kinetics. Frontiers in Bioengineering and Biotechnology, 10, 1032542.
Gillispie, G., Prim, P., Copus, J., Fisher, J., Mikos, A. G., Yoo, J. J., ... & Lee, S. J. (2020). Assessment methodologies for extrusion-based bioink printability. Biofabrication, 12(2), 022003.
Sardelli, L., Tunesi, M., Briatico-Vangosa, F., & Petrini, P. (2021). 3D-Reactive printing of engineered alginate inks. Soft Matter, 17(35), 8105-8117.

Current repository is composed fro three principal blocks:
- 1_BACKGROUND_REMOVER.py (removes background from image)
- 2_PORE_FACTOR.py (calculates pore factor)

## Requirements

The following Python libraries are required:

- os
- rembg
- PIL
- io
- OpenCV `cv2`
- numpy
- matplotlib
- import pandas as pd

## Description

### 1_BACKGROUND_REMOVER.py
This Python script removes the background from images in a specified input folder and saves the processed images to an output folder. It leverages the `rembg` library to perform background removal and works with common image formats like `.png`, `.jpg`, `.jpeg`, and `.bmp`. Examples of raw and processed images are shown on Fig.1 and Fig.2, respectively.

![Fig_1-min](https://github.com/user-attachments/assets/22cf2588-3627-4024-9e49-1d9b09277f3a)
Fig.1. Example of raw image.

![Fig_2-min](https://github.com/user-attachments/assets/0de22740-d19d-4daf-a460-bece61da06d8)
Fig.2. Example of processed image.

### 2_PORE_FACTOR.py
This Python code is designed to process a set of images from a specified directory using various image processing techniques and allow dynamic adjustment of processing parameters through sliders. The key tasks and capabilities of the code are:
- Image loading: the code loads image files (.jpeg, .png, .bmp, etc.) from a specified input directory;
- Image processing: it applies a series of image processing techniques to the images, including:
Gaussian blur and median blur for noise reduction;
Binary thresholding;
Canny edge detection for identifying edges in the image (Fig.3);
Edge dilation for better detection;
Contour detection;
Object filtering by area and circularity (Fig.4);
Parameter adjustment: the code provides an interactive interface with sliders that allow dynamic adjustments of the following parameters: Canny edge detection thresholds (lower and upper); minimum edge size for contour detection; circularity threshold for contour selection; dilation kernel size; Gaussian and median blur kernel sizes; dynamic epsilon value for contour approximation; binary threshold value for segmentation;
- Pore factor calculation: for each valid contour, the code calculates the pore factor (a property related to the perimeter and area of the contour), and it stores this data along with the perimeter and area;
- Visualization: the processed images are displayed interactively, with the option to adjust the image processing parameters in real-time using the sliders;
- Data saving: after processing each image, the code saves: the processed image with contours drawn on it; a table of object data (perimeter, area, pore factor) to an Excel file for each image.

![Fig_3](https://github.com/user-attachments/assets/ecf438ba-d650-4126-8e96-a322b005f89d)
Fig.3. Canny edge detection of defined object.

![Fig_4](https://github.com/user-attachments/assets/93cebab1-16a4-4bc2-b1be-e2672f707a40)
Fig.4. Detected morphologically closed objects. 

## Notes
Ensure that the images you are using are of good quality with clear object boundaries for better edge detection results.
The program can be adapted to process a larger variety of images by adjusting the parameters.

## License
This code is licensed under the MIT License. See the LICENSE file for more details.
