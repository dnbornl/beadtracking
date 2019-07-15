function I = imframe(varargin)
%IMFRAME Get one or more frames from an image stack.
%   I = IMFRAME(FILENAME) reads the input image and loads the first frame.
%
%   I = IMFRAME(FILENAME,INDICES) loads the specified frame(s). INDEX can 
%   be a positive scalar, a vector of positive integers, or 'all'.
%
%   [___] = IMFRAME(___,Name,Value) uses additional parameter name-value 
%   pairs. Valid parameters include:
%
%       'Class'         String indicating the desired class for the output.
%                       Valid options are 'double', 'single', 'int16',
%                       'uint8', 'uint16', and 'same' (make the output
%                       class identical to the input class).
%
%                       Default: 'same'
%
%       'Normalize'     Logical scalar that determines whether to normalize
%                       the image frames to the range [0,1].
%
%                       Default: true
%
%   Notes:
%   1) This function may become deprecated soon. Use TIFFREAD instead.
%
%   See also IMFINFO, IMREAD, MAT2GRAY, TIFFREAD.

% Copyright 2016-2017 Matthew R. Eicholtz

% Defaults
defaults = struct(...
    'Filename','mri.tif',...
    'Indices',1,...
    'Class','same',...
    'Normalize',true);

% Parse inputs
[filename,indices,datatype,normalize] = parseinputs(defaults,varargin{:});

% Initialize output
temp = imread(filename);
[m,n,p] = size(temp);
q = length(indices);
I = zeros(m,n,p,q,'like',temp);
if strcmp(datatype,'same')
    datatype = class(I);
end

% Read each specified frame and store in output array
for ii=1:q
    I(:,:,:,ii) = imread(filename,indices(ii));
end

% Normalize the data, if requested
if normalize
    I = mat2gray(I);
end

% Convert to requested data type
% try
%     eval(sprintf('I = im2%s(I);',datatype));
% catch
%     error('Unrecognized CLASS. Check inputs.');
% end
switch datatype
    case 'double'
        I = im2double(I);
    case 'single'
        I = im2single(I);
    case 'int16'
        I = im2int16(I);
    case 'uint8'
        I = im2uint8(I);
    case 'uint16'
        I = im2uint16(I);
    otherwise
        error('Unrecognized CLASS. Check inputs.');
end

end

%% Helper functions
function varargout = parseinputs(defaults,varargin)
%PARSEINPUTS Custom input parsing function.
    p = inputParser;
    
    p.addOptional('filename',defaults.Filename,@ischar);
    p.addOptional('indices',defaults.Indices,@(x) isnumeric(x) || strcmp(x,'all'));
    p.addParameter('class',defaults.Class,@(x) ischar(x) && ismember(x,...
        {'double','single','int16','uint8','uint16','same'}));
    p.addParameter('normalize',defaults.Normalize,@islogical);
    
    p.parse(varargin{:});
    
    [datatype,filename,indices,normalize] = struct2vars(p.Results);
    info = imfinfo(filename);
    N = length(info); %number of available frames
    if strcmp(indices,'all')
        indices = 1:N;
    end
    
    varargout = {filename,indices,datatype,normalize};
end

