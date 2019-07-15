%DEMO.LOGFILTER Demonstrate Laplacian-of-Gaussian (LoG) filters.
%   This script applies a series of LoG filters to a synthetic image 
%   containing four white circles of varying size on a black background.
%
%   Notes: 
%   1) This script requires the Computer Vision Toolbox.
%
%   2) The colors of the detected circles in the last figure are
%   proportional to filter score (i.e. higher scores indicate higher
%   confidence of the presence of a circle at that location).
%
%   See also INSERTSHAPE, FSPECIAL, IMFILTER, IMREGIONALMIN.

% Copyright 2016-2019 Matthew R. Eicholtz
clear; clc; close all;

%% Create synthetic image
wid = 200; hei = 200;
I = zeros(hei,wid); % black background

% Add four white circles of varying size
radii = [5,10,15,20]; % radii
I = insertShape(I,'FilledCircle',[0.25*wid 0.25*hei radii(1)],'Color','white','Opacity',1);
I = insertShape(I,'FilledCircle',[0.75*wid 0.25*hei radii(2)],'Color','white','Opacity',1);
I = insertShape(I,'FilledCircle',[0.75*wid 0.75*hei radii(3)],'Color','white','Opacity',1);
I = insertShape(I,'FilledCircle',[0.25*wid 0.75*hei radii(4)],'Color','white','Opacity',1);

I = rgb2gray(I); % convert from RGB (for imfilter)

figure(1);
imshow(I);
title('synthetic image');

%% Apply LoG filters
N = length(radii); % number of LoG filters
sigma = radii/sqrt(2); % standard deviation of LoG filters
hsize = 2*ceil(3*sigma)+1; % size of LoG filters

figure(2);
sgtitle('filter responses')
J = zeros([size(I),N]);
for ii=1:N
    h{ii} = fspecial('log',hsize(ii),sigma(ii));
    J(:,:,ii) = imfilter(I,h{ii},'replicate','conv');
    J(:,:,ii) = J(:,:,ii)-sum(h{ii}(h{ii}<0));
    J(:,:,ii) = J(:,:,ii)/sum(sum(abs(h{ii})));
    
    % Show results
    subplot(ceil(sqrt(N)),ceil(sqrt(N)),ii);
    imshow(J(:,:,ii),[]);
    title(sprintf('%s = %0.2f','\sigma',sigma(ii)));
end

%% Extract local minima
figure(3);
sgtitle('local minima');
minima = cell(N,1);
score = cell(N,1);
for ii=1:N
    bw = imregionalmin(J(:,:,ii));
    stats = regionprops(bw,J(:,:,ii),'Centroid','MeanIntensity');
    xy = reshape([stats(:).Centroid],2,[])';
    r = sqrt(2)*sigma(ii)*ones(size(xy,1),1);
    s = [stats(:).MeanIntensity]';
    
    minima{ii} = [xy, r];
    score{ii} = s;
    
    % Show results
    subplot(ceil(sqrt(N)),ceil(sqrt(N)),ii);
    imshow(imregionalmin(J(:,:,ii)));
    title(sprintf('%s = %0.2f','\sigma',sigma(ii)));
end

%% Show detected circles with color and opacity as a function of score
figure(4);
sgtitle('detected circles (dark red is highest score)');
cmap = jet(100);
for ii=1:N
    subplot(ceil(sqrt(N)),ceil(sqrt(N)),ii);
    imshow(ones(size(I)));
    x = minima{ii}(:,1);
    y = minima{ii}(:,2);
    r = minima{ii}(:,3);
    s = (1-score{ii})/(1-min(score{ii}));
    clr = cmap(ceil(s*100),:);
    circles(x,y,r,'EdgeColor','none','FaceColor',clr,'FaceAlpha',s);
    title(sprintf('%s = %0.2f','\sigma',sigma(ii)));
end

