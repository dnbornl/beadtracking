%DEMO.RECTANGLES Demonstrate the RECTANGLES function.
%   This script creates a grid of rectangle positions, then plots the
%   rectangles as a single patch using the RECTANGLES function. Various
%   combinations of color, transparency, and line properties are
%   demonstrated.
%
%   See also RECTANGLES.

% Copyright 2016-2019 Matthew R. Eicholtz
clear; clc; close all;

% Set the following parameters
alim = [200 200]; %[ax ay] -> axis limits, i.e. size of grid for rectangles
spacing = [10 10]; %[dx dy] -> rectangle spacing in x and y directions
maxrectsize = [17 17]; %maximum width and height of each rectangle

% Computing array of rectangle positions
dx = spacing(1); dy = spacing(2);
[x,y] = meshgrid(dx:dx:alim(1)-1,dy:dy:alim(2)-1);
x = x(:);
y = y(:);

wid = randi(maxrectsize(1),size(x))+1;
hei = randi(maxrectsize(2),size(x))+1;

pos = [x-wid/2,y-hei/2,wid,hei];

% Default settings
figure; set(gcf,'Name','Default settings');
axes; set(gca,'XTick',[],'YTick',[],'Box','on','XLim',[0 alim(1)],'YLim',[0 alim(2)]);
axis equal;
rect1 = rectangles(pos);

% Shuffled colors for faces
figure; set(gcf,'Name','Shuffled face colors');
axes; set(gca,'XTick',[],'YTick',[],'Box','on','XLim',[0 alim(1)],'YLim',[0 alim(2)]);
axis equal;
rect2 = rectangles(pos,'FaceColor','shuffle');

% Shuffled colors for edges
figure; set(gcf,'Name','Shuffled edge colors');
axes; set(gca,'XTick',[],'YTick',[],'Box','on','XLim',[0 alim(1)],'YLim',[0 alim(2)]);
axis equal;
rect3 = rectangles(pos,'EdgeColor','shuffle');

% Blue rectangles with dotted orange edges
figure; set(gcf,'Name','Blue rectangles with dotted orange edges');
axes; set(gca,'XTick',[],'YTick',[],'Box','on','XLim',[0 alim(1)],'YLim',[0 alim(2)]);
axis equal;
rect4 = rectangles(pos,'FaceColor','b','EdgeColor',[0.9294,0.6941,0.1255],...
    'LineStyle',':','LineWidth',2);

% Jet rectangles with random transparency
figure; set(gcf,'Name','Jet rectangles with random transparency');
axes; set(gca,'XTick',[],'YTick',[],'Box','on','XLim',[0 alim(1)],'YLim',[0 alim(2)]);
axis equal;
rect5 = rectangles(pos,'FaceColor',jet(size(pos,1)),'EdgeColor','none',...
    'FaceAlpha',rand(size(pos,1),1));

