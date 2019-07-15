function varargout = path(varargin)
%PATH Get path to relevant directories for the Bead-Tracking Toolbox.
%   S = BEADTRACKING.PATH returns the root directory of the toolbox.
%
%   BEADTRACKING.PATH, by itself, prints the root directory fullpath to the 
%   Command Window.
%
%   ROOT = BEADTRACKING.PATH(OPTION1,OPTION2,___) returns the path to a 
%   directory based on one or more user-specified options. Check code for 
%   valid options.
%
%   See also FILEPARTS, FULLFILE.

%	Copyright 2016-2019 Matthew R. Eicholtz

% Get root directory of toolbox
p = mfilename('fullpath');
root = fileparts(fileparts(p));

% Parse input options
options = strjoin(varargin,' ');
if nargin~=0
    switch lower(options)
        case 'insert case here'
            folder = '';
        otherwise
            error('Invalid OPTIONS: %s. Check inputs.',options);
    end
    root = fullfile(root,folder);
end

% Check to make sure the root exists
if exist(root,'dir')==0
    warning('The following path does not exist: %s',root);
end

% Return result based on output arguments
if nargout==0 %print to command window
    disp(root);
else %return path
    varargout = {root};
end

end

