function blobrefine(varargin)
%BLOBREFINE Remove stationary blobs.
%   BLOBREFINE(FILENAME) refines
%
%   BLOBREFINE(...,'ParamName',ParamValue,...) uses additional parameter
%   name-value pairs. Valid parameters include:
%
%       'Scale'         Vector of real-valued numbers indicating the linear
%                       scale of each LoG filter. As a rule of thumb, a
%                       scale of 't' corresponds to a filter that picks up
%                       on blobs with an estimated radius of
%                       exp(t)*sqrt(2). So, if you want to detect circles
%                       with a radius of 5, for example, then include
%                       t=log(5/sqrt(2)) (=1.26) in your vector.
%
%                       Default: -0.3:0.1:2 (24 filters for radii ranging
%                       from ~1 to ~10 pixels)
%
%       'Sensitivity'   Scalar indicating how many of the detected local
%                       minima to store for future use.
%
%                       Default: 0.97
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
%   See also IMREAD, IMFINFO, FSPECIAL, IMFILTER, IMREGIONALMIN,
%   REGIONPROPS, NMS.

% Copyright 2016 Matthew R. Eicholtz

%% Default parameter values
default = struct(...
    'Filename',[],...
    'Scale',-0.3:0.1:2,...
    'Sensitivity',0.97,...
    'Verbose',true);

%% Parse inputs
[filename,t,sens,verbose] = parseinputs(default,varargin{:});
if isempty(filename)
    fprintf('No filename selected. Exiting function.\n');
    return;
end

info = imfinfo(filename);

m = length(t); %number of filters
n = length(info); %number of frames

status('initial');

%% Generate filters
status('make filters');
sigma = exp(t); %log scale
hsize = 2*ceil(2*sigma)+1; %filter size
for ii=1:m
    h{ii} = fspecial('log',hsize(ii),sigma(ii));
end

%% Apply filters
status('start detection')
blobs = cell(n,1);
for ii=1:n
    status('detect',ii);
    
    % Read image frame
    I = imread(filename,'Index',ii,'Info',info);
    I = mat2gray(I);

    % For each filter, extract local minima and corresponding scores
    % (i.e. filter response)
    minima = [];
    score = [];
    for jj=1:length(h)
        J = imfilter(I,h{jj},'replicate','conv');
        J = J-sum(h{jj}(h{jj}<0));
        J = J/sum(sum(abs(h{jj})));

        bw = imregionalmin(J);
        
        [y,x] = find(bw);
        xy = [x,y];
        
%         stats = regionprops(bw,J,'Centroid','MeanIntensity');
%         xy2 = reshape([stats(:).Centroid],2,[])';
        
        minima = [minima; xy, sqrt(2)*sigma(jj)*ones(size(xy,1),1)];
        score = [score; J(bw)];
        
%         score = [score; [stats(:).MeanIntensity]'];
    end

    % Sort local minima by ascending score
    [score,order] = sort(score);
    minima = minima(order,:);
    
    % Apply sensitivity threshold
%     z = conv(score,ones(100,1)/100,'same');
%     ind = find(z>sens*max(score),1,'first');
    ind = min(10000,size(minima,1));
    minima = minima(1:ind,:);
    score = score(1:ind);
    
    % Apply non-minima suppression
    [minima,score] = nms(minima,score,'min');
    
    % Store detections
    blobs{ii} = [minima, score];
end

%% Save results
[p,f,~] = fileparts(filename);
if ~isempty(p)
    savefile = fullfile(p,strcat(f,' blobs.mat'));
else
    savefile = strcat(f,' blobs.mat');
end
save(savefile,'blobs','t','sens');

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
            fprintf('%s\tDetecting blobs in image sequence...\n',datestr(now));
            
        case 'detect'
            fprintf('%s\t\tFrame %d...\n',datestr(now),varargin{1});
            
        otherwise
            error('Unrecognized MESSAGE');
            
    end
end

end

%% Helper functions
function varargout = parseinputs(default,varargin)
    p = inputParser;
    
    p.addOptional('filename',default.Filename,@ischar);
    p.addParameter('scale',default.Scale,...
        @(x) validateattributes(x,{'numeric'},{'vector','real','finite','nonempty','nonsparse'}));
    p.addParameter('sensitivity',default.Sensitivity,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>=',0,'<=',1}));
    p.addParameter('verbose',default.Verbose,...
        @(x) validateattributes(x,{'logical'},{'scalar'}));
    
    p.parse(varargin{:});
    
    [filename,t,sens,verbose] = struct2vars(p.Results);
    
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
    
    varargout = {filename,t,sens,verbose};
end

