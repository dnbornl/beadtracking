function rmpaths(option)
%RMPATHS Remove relevant folders to search path.
%   RMPATHS(OPTION) removes relevant folders based on the input OPTION. 
%   Valid options include:
%
%       'default'   Default folders required for general use of the 
%                   Bead-Tracking Toolbox. Includes temp scripts, utility
%                   functions, and primary project directories.
%                   OPTION = 'default' if no input is provided.
%
%   See also RMPATH, GENPATH, ADDPATHS.

% Copyright 2018-2019 Matthew R. Eicholtz

cwd = beadtracking.path;
thirdparty = fullfile(cwd,'3rdparty');

if ~exist('option','var') || isempty(option)
    option = 'default';
end

switch lower(option)
    case 'default'
        rmpath(fullfile(cwd,'scripts'));
        rmpath(fullfile(cwd,'temp'));
        rmpath(fullfile(cwd,'utils'));
        rmpath(thirdparty);
        
    otherwise
        error('Unrecognized OPTION: %s',option);
end

end

