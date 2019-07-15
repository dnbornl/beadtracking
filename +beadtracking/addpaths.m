function addpaths(option)
%ADDPATHS Add relevant folders to search path.
%   ADDPATHS(OPTION) adds relevant folders based on the input OPTION. Valid
%   options include:
%
%       'default'   Default folders required for general use of the 
%                   Bead-Tracking Toolbox. Includes temp scripts, utility
%                   functions, and primary project directories.
%                   OPTION = 'default' if no input is provided.
%
%   See also ADDPATH, GENPATH, RMPATHS.

% Copyright 2018-2019 Matthew R. Eicholtz

cwd = beadtracking.path;
thirdparty = fullfile(cwd,'3rdparty');

if ~exist('option','var') || isempty(option)
    option = 'default';
end

switch lower(option)
    case 'default'
        addpath(fullfile(cwd,'scripts'));
        addpath(fullfile(cwd,'temp'));
        addpath(fullfile(cwd,'utils'));
        addpath(thirdparty);
        
    otherwise
        error('Unrecognized OPTION: %s',option);
end

end

