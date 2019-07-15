%DEMO.IMBLOBS Demonstrate the IMBLOBS function.
%   This script demonstrates the IMBLOBS function on a simple example -- 
%   detecting coins in an image. This is the same code listed in the help 
%   documentation of imblobs.
%
%   See also IMBLOBS.

% Tags: object detection, blob detection, LoG filter

% Copyright 2016-2019 Matthew R. Eicholtz
clear; clc; close all;

%% Load the sample image
I = imread('coins.png');

%% Choose parameters for blob detection
radii = 20:30; %radii of blobs to detect
sens = 0.4; %sensitivity of detection (the higher the value, the more detections you get)
[blobs,scores] = imblobs(I,...
    'Polarity','bright',...
    'Radii',radii,...
    'Sensitivity',sens,...
    'Verbose',true);

%% Show the results
h = figure(sum(mfilename+0));
h.Name = 'demoBlobDetection';
h.NumberTitle = 'off';
h.MenuBar = 'none';
h.ToolBar = 'none';
imshow(I);
viscircles(blobs(:,1:2),blobs(:,3));

