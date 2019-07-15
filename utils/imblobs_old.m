function [blobs,scores] = imblobs(varargin)
%IMBLOBS Extract blobs in an image using LoG filters.
%   BLOBS = IMBLOBS(FILENAME) reads an input image sequence and detects
%   circular blobs in each frame using a set of Laplacian of Gaussian (LoG)
%   filters. The output is an M-by-3 array, where each row contains the
%   position and size of a detected blob (i.e. [x y r]).
%
%   [BLOBS,SCORES] = 
%
%   IMBLOBS(...,'ParamName',ParamValue,...) uses additional parameter
%   name-value pairs. Valid parameters include:
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
%       'Scale'         Vector of real-valued numbers indicating the radii
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
%                       Default: true
%
%   Notes:
%   1) Here is an online reference demonstrating a similar approach.
%   http://www.cs.utah.edu/~jfishbau/advimproc/project1/
%
%   Example:
%   1) Detect coins in an image:
%
%       [blobs,scores] = imblobs('coins.png',...
%           
%
%   See also IMREAD, IMFINFO, FSPECIAL, IMFILTER, IMREGIONALMIN,
%   REGIONPROPS, NMS.

% Copyright 2016 Matthew R. Eicholtz

%% Default parameter values
default = struct(...
    'Filename',[],...
    'Polarity','bright',...
    'Scale',1:10,...
    'Sensitivity',0.49,...
    'Verbose',true);

%% Parse inputs
[filename,polarity,radii,sens,verbose] = parseinputs(default,varargin{:});
if isempty(filename)
    fprintf('No filename selected. Exiting function.\n');
    return;
end

info = imfinfo(filename);

m = length(radii); %number of filters
n = length(info); %number of frames

status('initial');

%% Generate filters
status('make filters');
t = log(radii./sqrt(2));
sigma = exp(t); %log scale
hsize = 2*ceil(2*sigma)+1; %filter size
h = cell(m,1); %initialize filters
for ii=1:m
    h{ii} = fspecial('log',hsize(ii),sigma(ii));
end

%% Apply filters
status('start detection')
blobs = cell(n,1); %initialize blobs
scores = cell(n,1); %initialize scores
for ii=1:n
    status('detect');
    
    % Read image frame
    if n==1
        I = imread(filename);
    else
        I = imread(filename,'Index',ii,'Info',info);
    end
    try I = rgb2gray(I); end
    I = mat2gray(I);

    % For each filter, extract local minima and corresponding scores
    % (i.e. filter response)
    optima = [];
    score = [];
    
    for jj=1:m
        J = imfilter(I,h{jj},'replicate','conv');
        J = J-sum(h{jj}(h{jj}<0));
        J = J/sum(sum(abs(h{jj})));
        
        switch polarity
            case 'bright'
                bw = imregionalmin(J);
            case 'dark'
                bw = imregionalmax(J);
        end
        
        [y,x] = find(bw);
        xy = [x,y];
        
%         stats = regionprops(bw,J,'Centroid','MeanIntensity');
%         xy2 = reshape([stats(:).Centroid],2,[])';
        
        optima = [optima; xy, sqrt(2)*sigma(jj)*ones(size(xy,1),1)];
        score = [score; J(bw)];
        
%         score = [score; [stats(:).MeanIntensity]'];
    end
    
    % Sort local minima by ascending score
    [score,order] = sort(score);
    optima = optima(order,:);
    
    % Apply sensitivity threshold
%     z = conv(score,ones(100,1)/100,'same');
%     ind = find(z>sens*max(score),1,'first');
%     ind = find(score>mean(score)*sens,1,'first');
%     ind = find(score>max(score)*sens,1,'first');
%     ind = min(10000,size(optima,1));
    ind = find(score>sens,1,'first');
    optima = optima(1:ind,:);
    score = score(1:ind);
    
    % Apply non-maxima/minima suppression
    switch polarity
        case 'bright'
            [optima,score] = nms(optima,score,'min');
        case 'dark'
            [optima,score] = nms(optima,score,'max');
    end
    
    % Store detections
    blobs{ii} = optima;
    scores{ii} = score;
end

% Convert from cell array if image is not multi-page TIF
if n==1
    blobs = blobs{1};
    scores = scores{1};
end

status('end');

%% Nested functions
function status(message,varargin)
%STATUS Print text in Command Window.
    if ~verbose; return; end
    
    switch message
        case 'initial'
            fprintf('\n==============================================================================\n');
            fprintf('\t\t\t\t\t\t\tBlob Detection\n\n');
            fprintf('Filename: %s\n',filename);
            fprintf('Number of frames: %d\n\n',n);
            
        case 'make filters'
            fprintf('%s\tGenerating %d Laplacian of Gaussian (LoG) filters\n',datestr(now),m);
            
        case 'start detection'
            if n==1
                fprintf('%s\tDetecting blobs in the image\n',datestr(now));
            else
                fprintf('%s\tDetecting blobs in image sequence...\n',datestr(now));
            end
            
        case 'detect'
            if n>1
                fprintf('%s\t\tFrame %d...\n',datestr(now),ii);
            end
            
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
    
    p.addOptional('filename',default.Filename,@ischar);
    p.addParameter('polarity',default.Polarity,...
        @(x) ismember(x,{'bright','dark'}));
    p.addParameter('scale',default.Scale,...
        @(x) validateattributes(x,{'numeric'},{'vector','real','finite','nonempty','nonsparse'}));
    p.addParameter('sensitivity',default.Sensitivity,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>=',0,'<=',1}));
    p.addParameter('verbose',default.Verbose,...
        @(x) validateattributes(x,{'logical'},{'scalar'}));
    
    p.parse(varargin{:});
    
    [filename,polarity,radii,sens,verbose] = struct2vars(p.Results);
    
    if isempty(filename)
        currdir = cd;
        try
            datadir = fullfile(fileparts(mfilename('fullpath')),'..','..','data','beadtracking');
            cd(datadir);
        catch
            warning('Could not locate directory: %s\nUsing current directory instead',datadir);
        end
        [filename,pathname] = uigetfile(...
            {'*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
            'Load Image Sequence From File');
        if ~isempty(filename) && ~isequal(filename,0)
            filename = fullfile(pathname,filename);
        else
            filename = [];
        end
        cd(currdir);
    end
    
    varargout = {filename,polarity,radii,sens,verbose};
end

