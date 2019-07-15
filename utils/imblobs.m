function [blobs,scores] = imblobs(varargin)
%IMBLOBS Extract blobs in an image using LoG filters.
%   BLOBS = IMBLOBS(I) detects circular blobs in an image using a set of 
%   Laplacian of Gaussian (LoG) filters. The output is an M-by-3 array, 
%   where each row contains the position and size of a detected blob 
%   (i.e. [x y r]).
%
%   [BLOBS,SCORES] = IMBLOBS(___) also returns the filter responses as an
%   M-by-1 vector of scores.
%
%   [___] = IMBLOBS(___,Name,Value) uses additional parameter name-value
%   pairs. Valid parameters include:
%
%       'Polarity'      String that specifies the polarity of the blob(s)
%                       with respect to the background. Available options
%                       are:
%                       
%                       'bright': blobs are brighter than the background
%                       'dark': blobs are darker than the background
%
%                       Default: 'bright'
%
%       'Radii'         Vector of real-valued numbers indicating the radii
%                       of blobs to detect. Each radius dictates the scale
%                       and size of the corresponding LoG filter.
%
%                       Default: [1:10]
%
%       'Sensitivity'   Numeric scalar indicating how many of the detected 
%                       local optima to store for future use. Must be in 
%                       the range [0,1].
%
%                       ***NOTE: the definition of this parameter keeps
%                       changing. Consult the code to see how it is
%                       actually used***
%
%                       Default: 0.49
%
%       'Verbose'       Logical scalar indicating whether to print details
%                       to the Command Window or not.
%
%                       Default: false
%
%   Notes:
%   1) Here is an online reference demonstrating a similar approach.
%   http://www.cs.utah.edu/~jfishbau/advimproc/project1/
%
%   Example:
%   1) Detect coins in an image:
%
%       I = imread('coins.png');
%       [blobs,scores] = imblobs(I,...
%           'Polarity','bright',...
%           'Radii',20:30,...
%           'Sensitivity',0.4,...
%           'Verbose',true);
%
%       imshow(I);
%       viscircles(blobs(:,1:2),blobs(:,3));
%
%   See also IMREAD, IMFINFO, FSPECIAL, IMFILTER, IMREGIONALMIN,
%   REGIONPROPS, NMS.

% Tags: object detection, blob detection, LoG filter

% Copyright 2016 Matthew R. Eicholtz

%% Default parameter values
default = struct(...
    'I',[],...
    'Polarity','bright',...
    'Radii',1:10,...
    'Sensitivity',0.49,...
    'Verbose',false);

%% Parse inputs
[I,fcn,radii,sens,verbose] = parseinputs(default,varargin{:});
if isempty(I)
    fprintf('No image has been provided. Exiting function.\n');
    return;
end

%% Setup filter parameters
sigma = radii/sqrt(2); %standard deviation
hsize = 2*ceil(2*sigma)+1; %filter size

%% Apply each filter
optima = [];
score = [];
for ii=1:length(radii)
    h = fspecial('log',hsize(ii),sigma(ii));
    c = sum(sum(abs(h))); %normalization constant
    J = imfilter(I,h,'replicate','conv');
    J = (J+c/2)/c;
    
    bw = fcn.findlocaloptima(J);
    [y,x] = find(bw);
    
    optima = [optima; x, y, radii(ii)*ones(size(x))];
    score = [score; J(bw)];
end

% Sort local optima
[score,order] = fcn.sort(score);
optima = optima(order,:);

% Apply sensitivity threshold
%     z = conv(score,ones(100,1)/100,'same');
%     ind = find(z>sens*max(score),1,'first');
%     ind = find(score>mean(score)*sens,1,'first');
%     ind = find(score>max(score)*sens,1,'first');
%     ind = min(10000,size(optima,1));
ind = find(fcn.compare(score,sens),1,'first');
optima = optima(1:ind,:);
score = score(1:ind);

% Apply non-maxima/minima suppression
[optima,score] = fcn.suppress(optima,score);

% Store detections
blobs = optima;
scores = score;

%% Nested functions
function status(message,varargin)
%STATUS Print text in Command Window.
    if ~verbose; return; end
    
    switch message
        case 'initial'
            fprintf('\n==============================================================================\n');
            fprintf('\t\t\t\t\t\t\tBlob Detection\n\n');
            
        case 'end'
            fprintf('%s\tBlob detection complete\n',datestr(now));
            fprintf('\n==============================================================================\n');
            
        otherwise
            error('Unrecognized MESSAGE');
            
    end
end

end

%% Helper functions
function varargout = parseinputs(default,varargin)
%PARSEINPUTS Custom input parsing function.
    p = inputParser;
    
    p.addOptional('I',default.I,...
        @(x) validateattributes(x,{'numeric'},{'3d'}));
    p.addParameter('polarity',default.Polarity,...
        @(x) ismember(x,{'bright','dark'}));
    p.addParameter('radii',default.Radii,...
        @(x) validateattributes(x,{'numeric'},{'vector','real','finite','nonempty','nonsparse'}));
    p.addParameter('sensitivity',default.Sensitivity,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>=',0,'<=',1}));
    p.addParameter('verbose',default.Verbose,...
        @(x) validateattributes(x,{'logical'},{'scalar'}));
    
    p.parse(varargin{:});
    
    [I,polarity,radii,sens,verbose] = struct2vars(p.Results);
    
    if isempty(I)
        currdir = cd;
        try
            datadir = fullfile(fileparts(mfilename('fullpath')),'..','..','..','data','beadtracking');
            cd(datadir);
        catch
            warning('Could not locate directory: %s\nUsing current directory instead',datadir);
        end
        [filename,pathname] = uigetfile(...
            {'*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
            'Load Image From File');
        if ~isempty(filename) && ~isequal(filename,0)
            I = imread(fullfile(pathname,filename));
            I = mat2gray(I);
        else
            I = [];
        end
        cd(currdir);
    else
        I = mat2gray(I);
    end
    
    switch polarity
        case 'bright'
            fcn.findlocaloptima = @imregionalmin;
            fcn.sort = @(x) sort(x,'ascend');
            fcn.suppress = @(x,y) nms(x,y,'min');
            fcn.compare = @(x,y) x>y;
            
        case 'dark'
            fcn.findlocaloptima = @imregionalmax;
            fcn.sort = @(x) sort(x,'descend');
            fcn.suppress = @(x,y) nms(x,y,'max');
            fcn.compare = @(x,y) x<y;
    end
    
    varargout = {I,fcn,radii,sens,verbose};
end

