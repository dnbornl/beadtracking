# Bead-Tracking Toolbox in MATLAB

## Purpose

This toolbox was specifically created for automatically detecting and tracking fluorescent microbeads in high-resolution microscopy images.

The code was developed by the Imaging, Signals, and Machine Learning Group at Oak Ridge National Laboratory in collaboration with the Developmental Neurobiology Department at St. Jude Children's Research Hospital.

## Installation

Download the latest version of the toolbox by clicking on "Clone or download" of this GitHub repository, selecting the appropriate option, and following the corresponding prompts.

## Requirements

The software requires MATLAB (R2018a or later) and the following toolboxes:

* Image Processing Toolbox (v9.4 or later)
* Computer Vision Toolbox (v8.1 or later)
* Statistics and Machine Learning Toolbox (v11.3 or later)

## Usage

Navigate to the main toolbox directory in MATLAB. Then, add the relevant folders to your MATLAB search path using

`beadtracking.addpaths`

Next, install the Bead Tracker app (double-click *apps/BeadTracker/Bead Tracker.mlappinstall* and select "Install").

Most users will use the app along with code located in the scripts/ directory. Specifically, to process a sequence of microscopy images stored as a single TIFF file, follow these general steps:

**1. ROI selection:** Use the Bead Tracker app to load the image sequence, visually examine the beads using the video and zoom/pan controls, and draw a custom region-of-interest (ROI) using the ROI tab controls. Save the ROI using the "Save" icon on the ROI tab; use the same basename for the .mat file (i.e. if your image file is myimages.tif, then name your ROI file myimages.mat).

*NOTE: Drawing the ROI is not explicitly required for tracking beads, but it likely will help with pruning poor detections and yielding more reliable tracks, so it is highly recommended.

You do not need to close the app as you can use it as a visual tool for later steps in the process.

**2. runBlobDetection.m:** This script uses Laplacian of Gaussian (LoG) filters to detect blobs in images. Modify the parameters at the top of the script to suit your data, and run the code. The radii and sensitivity parameters may need to be adjusted by trial-and-error. You can view detection results frame-by-frame by setting `showresults = true`. After you are satisfied with the results, make sure to run the script with `saveresults = true`. This will automatically append the detection results to the file with the ROI from step 1.

**3. runBlobRefinement.m:** *(optional)* This script uses one or more techniques to refine the detections found in step 2. See the script documentation for a detailed description of the available methods. Modify the parameters at the top of the script to suit your data, and run the code. Once again, some of the thresholds may need to be adjusted by trial-and-error. If you set `saveresults = true`, the refinement results will be saved in the mat-file (separate from the detection results - i.e. detections are not overwritten).

**4. App visualization:** *(optional)* As mentioned in (1), if you kept the app open, you can now view the (refined) detections using the app controls. Navigate to the Tracking tab, click on "Load Detections", and select the appropriate file. Then, you can run the default tracking algorithm by clicking "Start Tracking"; use this to get a general sense for tracking performance and to leverage zoom/pan controls for close-up analysis.

*NOTE: Tracking results in the app are NOT currently saved.*

**5. runKalmanTracking.m:** This script uses Kalman filters to track detected beads over time. It is the same algorithm used in the app, but the script allows you to tweak parameters for your needs and save the results. Modify the parameters at the top of the script to suit your data, and run the code. Adjusting the filter parameters (contained in the `params` structure) may require prior knowledge of Kalman filtering; [this similar example](https://www.mathworks.com/help/vision/examples/motion-based-multiple-object-tracking.html "Motion-Based Multiple-Object Tracking") may be a good reference to learn more.

**6. showTrackingResults.m:** *(optional)* Assuming you have set `saveresults = true` in all the previous steps, you are ready to analyze the detection and tracking results. A sample script (showTrackingResults.m) is provided with some basic analysis outcomes. Modify the parameters at the top of the script to suit your data, and run the code. Feel free to add new `options` that suit your project needs. Currently, you can generate videos of one or more tracked objects as well as still images with overlaid tracks and the corresponding bead speed.

## Updates

* July 2019 - Version 2.0 released

## Bug fixes

None at this time.

