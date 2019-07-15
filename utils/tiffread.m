function I = tiffread(varargin)
%TIFFREAD Read multi-image TIFF file.
%   I = TIFFREAD(FILENAME) reads the input image volume.
%
%   I = TIFFREAD(FILENAME,INDICES) loads the specified frame(s). INDICES 
%   can be a positive scalar, a vector of positive integers, or 'all'
%   (default, if excluded).
%
%   [___] = TIFFREAD(___,Name,Value) uses additional parameter name-value
%   pairs. Valid parameters include:
%
%       'Squeeze'       Logical scalar indicating whether to remove
%                       singleton dimensions or not. For grayscale images,
%                       the output will by M-by-N-by-P when 'Squeeze' is
%                       true and M-by-N-by-1-by-P otherwise.
%
%                       Default: true
%
%       'Version'       Scalar indicating which method to use for reading
%                       the TIFF file. Available methods are:
%
%                       1 - imread
%                       2 - Tiff object
%
%                       Default: 2
%
%   Notes
%   -----
%   1. This function is only valid if all image frames are the same size.
%
%   Example 1
%   ---------
%   Read three-dimensional MRI grayscale data from file:
%
%       I = tiffread('mri.tif');
%
%   Example 2
%   ---------
%   Read a series of color images from file:
%
%       I = tiffread('trees.tif',[2,3,4,6,7]);
%
%   See also IMFINFO, IMREAD, SQUEEZE, TIFF.

%   Copyright 2016 Matthew R. Eicholtz

% Default parameter values
default = struct(...
    'Filename',[],...
    'Indices','all',...
    'Squeeze',true,...
    'Version',2);

% Parse inputs
[filename,ind,squeezedata,v] = parseinputs(default,varargin{:});
if isempty(filename); return; end
q = length(ind); %number of images

% Which version to run?
switch v
    case 1 %use imread
        % Initialize output
        info = imfinfo(filename);
        [X,map] = imread(filename,'tif','Index',ind(1),'Info',info);
        if isempty(map) || isequal(map(:,1),map(:,2),map(:,3))
            [m,n,p] = size(X);
            I = zeros(m,n,p,q,'like',X);
        else
            [m,n,~] = size(X); p = 3;
            I = zeros(m,n,p,q,'double');
        end

        % Read each specified frame and store in output array
        for ii=1:q
            [X,map] = imread(filename,'Index',ind(ii),'Info',info);
            if p==1 || isempty(map)
                I(:,:,:,ii) = X;
            else
                I(:,:,:,ii) = ind2rgb(X,map);
            end
        end
        
    case 2 %use Tiff object
        obj = Tiff(filename,'r');
        info = imfinfo(filename);
        [X,~] = imread(filename,'tif','Index',ind(1),'Info',info);
        I = zeros(info(1).Height,info(1).Width,q,'like',X);
        for ii=1:q
            obj.setDirectory(ind(ii));
            I(:,:,ii) = obj.read();
        end
        
    otherwise
        error('Unrecognized version request: %d',v);
end

% Remove singleton dimensions, if requested
if squeezedata; I = squeeze(I); end

end

%% Helper functions
function varargout = parseinputs(default,varargin)
    p = inputParser;
    
    p.addOptional('filename',default.Filename,@(x) isempty(x) || ischar(x));
    p.addOptional('indices',default.Indices,@(x) isnumeric(x) || strcmp(x,'all'));
    p.addParameter('squeeze',default.Squeeze,@islogical);
    p.addParameter('version',default.Version,@(x) isnumeric(x) && isscalar(x));
    
    p.parse(varargin{:});
    
    filename = p.Results.filename;
    ind = p.Results.indices;
    squeezedata = p.Results.squeeze;
    v = p.Results.version;
    
    if isempty(filename)
        [f,p,~] = uigetfile({'*.tif;*.tiff','TIFF-files (*.tif, *.tiff)'});
        if isequal(f,0) || isempty(f)
            disp('No file selected. Exiting function.');
            varargout = {[],[],[],[],[]};
            return;
        end
        filename = fullfile(p,f);
    end
    
    info = imfinfo(filename);
    N = length(info); %number of available frames
    if strcmp(ind,'all')
        ind = 1:N;
    end
    
    varargout = {filename,ind,squeezedata,v};
end

