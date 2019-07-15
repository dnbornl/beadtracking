%DEMO.OPTICALFLOW Demonstrate built-in optical flow algorithms.
%   This script computes and displays the frame-by-frame optical flow for a
%   sequence of images. Feel free to adjust the optical flow parameters to
%   find values suitable for the application at hand.
%
%   Notes: 
%   1) This script requires the Computer Vision Toolbox.
%
%   2) There are sample image sequences in the resources folder of the
%   Bead-Tracking Toolbox.
%
%   See also OPTICALFLOWHS, OPTICALFLOWLK, OPTICALFLOWLKDOG, 
%   OPTICALFLOWFARNEBACK, QUIVER.

% Copyright 2016-2019 Matthew R. Eicholtz
clear; clc; close all;

%% Get sequence of images
filename = fullfile(beadtracking.path,'resources','demos','motion03.tif');
I = imframe(filename,'all','class','uint8');
[hei,wid,channels,frames] = size(I);

%% Setup optical flow
opticFlow = opticalFlowHS;
opticFlow.Smoothness = 1;
opticFlow.MaxIteration = int32(10);
opticFlow.VelocityDifference = 0;

offset = 1; %offset
d = 10; %decimation
s = 50; %scaling

%% Show optical flow over frames
figure(1);
himage = imshow(I(:,:,:,1));
hold on;
hquiver = quiver(0,0,0,0,0);
hquiver.Color = 'g';
hold off;
U = zeros([hei,wid,frames]);
V = zeros([hei,wid,frames]);
for ii=1:frames
    himage.CData = I(:,:,:,ii);
    f(ii) = estimateFlow(opticFlow,I(:,:,:,ii));
    
%     Vx = imdilate(f(ii).Vx,ones(d-1));
%     Vy = imdilate(f(ii).Vy,ones(d-1));
    
    [row,col] = size(f(ii).Vx);
    rowsub = offset:d:(row-offset+1);   
    colsub = offset:d:(col-offset+1);   
    [x,y] = meshgrid(colsub,rowsub);
    ind = sub2ind([row,col],y(:),x(:));
    u = f(ii).Vx(ind);
    v = f(ii).Vy(ind);
    u = u.*s;
    v = v.*s;
    
    U(:,:,ii) = s*f(ii).Vx;
    V(:,:,ii) = s*f(ii).Vy;
    
    hquiver.XData = x(:);
    hquiver.YData = y(:);
    hquiver.UData = u(:);
    hquiver.VData = v(:);
    pause(0.02)
end

%% Show optical flow summary
figure(2);
imshow(ones(hei,wid));
hold on;
q = quiver(mean(U,3),mean(V,3),'autoscale','off');
q.Color = 'g';
hold off;

